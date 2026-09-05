import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/connection/runtime_network_policy.dart';
import 'package:onexray/service/routing/region_catalog.dart';
import 'package:onexray/service/routing/state.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/runtime_inbounds.dart';
import 'package:onexray/service/xray/runtime_outbounds.dart';

class ResolvedServer {
  final int id;
  final int sourceId;
  final String name;
  final String outboundJson;

  ResolvedServer({
    required this.id,
    required this.sourceId,
    required Map<String, dynamic> outbound,
  }) : name = outboundDisplayName(outbound),
       outboundJson = jsonEncode(outbound);

  factory ResolvedServer.fromRow(CoreConfigData row) {
    if (row.type != 'outbound') {
      throw const FormatException('A server must be an outbound');
    }
    return ResolvedServer(
      id: row.id,
      sourceId: row.subId,
      outbound: readOutboundFromDbData(row),
    );
  }

  Map<String, dynamic> get outbound =>
      jsonDecode(outboundJson) as Map<String, dynamic>;
  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'name': name,
    'outbound': outbound,
  };
}

class RuntimeOptions {
  final ConnectionPlatform platform;
  final String sessionDirectory;
  final int metricsPort;
  final int socksPort;
  final bool ipv6;
  final String interfaceName;
  final bool logEnabled;
  final bool logFilesSupported;
  final String logLevel;
  final bool dnsLog;
  final String maskAddress;
  final Map<String, List<String>> bootstrapAddresses;

  RuntimeOptions({
    required this.platform,
    required this.sessionDirectory,
    required this.metricsPort,
    required this.socksPort,
    this.ipv6 = true,
    this.interfaceName = '',
    this.logEnabled = false,
    this.logFilesSupported = true,
    this.logLevel = 'warning',
    this.dnsLog = true,
    this.maskAddress = '',
    Map<String, List<String>> bootstrapAddresses = const {},
  }) : bootstrapAddresses = Map.unmodifiable(
         bootstrapAddresses.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       ) {
    for (final port in [metricsPort, socksPort]) {
      if (port < 1 || port > 65535) {
        throw const FormatException('Invalid runtime port');
      }
    }
    if (metricsPort == socksPort) {
      throw const FormatException('Runtime ports are invalid');
    }
    if ((platform == ConnectionPlatform.windows ||
            platform == ConnectionPlatform.linux) &&
        interfaceName.isEmpty) {
      throw const FormatException('Network interface is required');
    }
    if (!['debug', 'info', 'warning', 'error', 'none'].contains(logLevel) ||
        !['', 'quarter', 'half', 'full'].contains(maskAddress)) {
      throw const FormatException('Invalid logging policy');
    }
  }
}

class CompiledConnection {
  final String xrayJson;
  final List<ResolvedServer> entries;
  final ResolvedServer? finalExit;
  final Map<String, int> nodeTags;

  CompiledConnection({
    required this.xrayJson,
    required Iterable<ResolvedServer> entries,
    required this.finalExit,
    required Map<String, int> nodeTags,
  }) : entries = List.unmodifiable(entries),
       nodeTags = Map.unmodifiable(nodeTags);

  Map<String, dynamic> get config =>
      jsonDecode(xrayJson) as Map<String, dynamic>;
}

/// Pure value compilation. Never opens a database, edits an asset, allocates a
/// port or starts Xray. Runtime files and commits belong to the coordinator.
class ConnectionCompiler {
  static Map<String, dynamic> parseRawJson(String text) {
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Raw configuration must be an object');
    }
    return value;
  }

  /// Compare editor drafts through the same overrides as a real Raw runtime.
  /// The caller supplies identical options for both drafts; no files are written.
  static Map<String, dynamic> rawSemanticJson(
    String text,
    RuntimeOptions options,
  ) {
    final value = parseRawJson(text)..remove('name');
    return _rawRuntimeMap(value, options);
  }

  static const dnsProxy = 'app-dns-proxy';
  static const dnsDirect = 'app-dns-direct';
  static const dnsOutbound = 'dnsOut';
  static const ipv6Block = 'app-ipv6-block';

  /// The editor and runtime share these exact built-in rules and their order.
  static List<XrayRoutingRule> smartRules(
    SmartRoutingSettings smart,
    RegionCatalog regions,
  ) {
    final domains = <String>{
      if (smart.directPrivate) 'geosite:PRIVATE',
      if (smart.directApple) 'geosite:APPLE',
      ...regions.domainRules(smart.directRegions),
    }.toList();
    final ips = <String>{
      if (smart.directPrivate) 'geoip:PRIVATE',
      ...regions.ipRules(smart.directRegions),
    }.toList();
    return [
      if (smart.blockAds)
        XrayRoutingRule(
          ruleTag: 'app-smart-ads',
          domain: ['geosite:CATEGORY-ADS-ALL'],
          outboundTag: 'block',
        ),
      if (domains.isNotEmpty)
        XrayRoutingRule(
          ruleTag: 'app-smart-direct-domain',
          domain: domains,
          outboundTag: 'direct',
        ),
      if (ips.isNotEmpty)
        XrayRoutingRule(
          ruleTag: 'app-smart-direct-ip',
          ip: ips,
          outboundTag: 'direct',
        ),
    ];
  }

  static CompiledConnection compile({
    required ConnectionSettings settings,
    required List<ResolvedServer> entries,
    ResolvedServer? finalExit,
    Map<String, dynamic>? raw,
    RoutingProfileState? custom,
    required RegionCatalog regions,
    required RuntimeOptions options,
  }) {
    final nodeTags = <String, int>{};
    late final Map<String, dynamic> config;
    if (settings.expert) {
      if (raw == null || entries.isNotEmpty || finalExit != null) {
        throw const FormatException(
          'Raw configuration is required without normal nodes',
        );
      }
      config = _rawRuntimeMap(raw, options);
    } else {
      final required = settings.requiredEntries(
        customEntryCount: custom?.entryCount,
      );
      if (entries.length != required ||
          entries.map((entry) => entry.id).toSet().length != required) {
        throw const FormatException('Not enough distinct entry nodes');
      }
      if (settings.finalExitId != finalExit?.id ||
          entries.any((entry) => entry.id == finalExit?.id)) {
        throw const FormatException('Invalid final exit selection');
      }
      if (settings.selection.kind == SelectionKind.server &&
          entries.single.id != settings.selection.id) {
        throw const FormatException('Fixed server does not match');
      }
      if (settings.trafficMode == TrafficMode.custom && custom == null) {
        throw const FormatException('Custom route is required');
      }
      final rules = <XrayRoutingRule>[];
      var domainStrategy = 'AsIs';
      if (settings.trafficMode == TrafficMode.smart) {
        final smart = settings.smart;
        domainStrategy = smart.resolveIpOnNoMatch ? 'IPIfNonMatch' : 'AsIs';
        rules.addAll(smartRules(smart, regions));
      } else if (settings.trafficMode == TrafficMode.custom) {
        domainStrategy = custom!.domainStrategy;
        for (final (index, rule) in custom.rules.indexed) {
          rules.add(rule.xrayJson..ruleTag = 'app-custom-$index');
        }
      }
      final entriesOutbounds = <Map<String, dynamic>>[];
      final exits = <Map<String, dynamic>>[];
      final selector = <String>[];
      for (final (index, entry) in entries.indexed) {
        final entryTag = 'app-entry-$index';
        final outbound = _node(entry, entryTag);
        nodeTags[entryTag] = entry.id;
        entriesOutbounds.add(outbound);
        if (finalExit == null) {
          selector.add(entryTag);
        } else {
          final exitTag = 'app-exit-$index';
          final exit = _node(finalExit, exitTag);
          setOutboundDialerProxy(exit, entryTag);
          nodeTags[exitTag] = finalExit.id;
          exits.add(exit);
          selector.add(exitTag);
        }
      }
      final outbounds = <Map<String, dynamic>>[
        if (finalExit == null) ...entriesOutbounds else ...exits,
        if (finalExit != null) ...entriesOutbounds,
      ];
      _applyOutboundPolicy(outbounds, options, raw: false);
      outbounds.addAll([
        createFreedomOutbound(
          tag: 'direct',
          interfaceName:
              options.platform == ConnectionPlatform.windows ||
                  options.platform == ConnectionPlatform.linux
              ? options.interfaceName
              : null,
        ).toJson(),
        createBlackholeOutbound(tag: 'block').toJson(),
        createDnsOutbound(tag: dnsOutbound, dialerProxy: 'direct').toJson(),
      ]);
      final directDomains = <String>{};
      if (settings.trafficMode != TrafficMode.smart ||
          settings.smart.directDns) {
        for (final rule in rules.where(
          (rule) => rule.outboundTag == 'direct',
        )) {
          directDomains.addAll(rule.domain ?? []);
        }
      }
      final queryStrategy = options.ipv6 ? 'UseIP' : 'UseIPv4';
      config = XrayJson(
        env: XrayEnv(
          assetLocation: VpnConstants.datDir,
          certLocation: VpnConstants.datDir,
        ),
        inbounds: [_runtimeInbound(options)],
        log: _runtimeLog(options),
        stats: XrayStats(),
        metrics: XrayMetrics(listen: '127.0.0.1:${options.metricsPort}'),
        policy: XrayPolicy(system: _runtimeStatsPolicy()),
        outbounds: outbounds,
        observatory: XrayObservatory(subjectSelector: []),
        dns: XrayDns(
          servers: [
            XrayDnsServer(
              address: '8.8.8.8',
              tag: dnsProxy,
              queryStrategy: queryStrategy,
            ),
            XrayDnsServer(
              address: '8.8.8.8',
              tag: dnsDirect,
              domains: directDomains.toList(),
              skipFallback: true,
              queryStrategy: queryStrategy,
            ),
          ],
        ),
        routing: XrayRouting(
          domainStrategy: domainStrategy,
          balancers: [
            XrayBalancer(
              tag: 'proxy',
              selector: selector,
              strategy: XrayBalancingStrategy(type: 'roundRobin'),
              fallbackTag: 'block',
            ),
          ],
          rules: [
            if (!options.ipv6)
              XrayRoutingRule(
                ruleTag: ipv6Block,
                ip: ['::/0'],
                outboundTag: 'block',
              ),
            XrayRoutingRule(
              ruleTag: 'app-default',
              inboundTag: [dnsProxy],
              balancerTag: 'proxy',
            ),
            XrayRoutingRule(
              ruleTag: 'app-direct-dns',
              inboundTag: [dnsDirect],
              outboundTag: 'direct',
            ),
            XrayRoutingRule(
              ruleTag: 'app-tunnel-dns',
              inboundTag: ['tunIn'],
              port: '53',
              outboundTag: dnsOutbound,
            ),
            XrayRoutingRule(
              ruleTag: 'app-tunnel-dot',
              inboundTag: ['tunIn'],
              port: '853',
              balancerTag: 'proxy',
            ),
            ...rules,
          ],
        ),
      ).toJson();
    }
    return CompiledConnection(
      xrayJson: jsonEncode(config),
      entries: entries,
      finalExit: finalExit,
      nodeTags: nodeTags,
    );
  }

  static Map<String, dynamic> _node(ResolvedServer node, String tag) {
    final outbound = node.outbound;
    requireCanonicalOutbound(outbound);
    if (outboundDialerProxy(outbound)?.isNotEmpty == true ||
        outboundProxyTag(outbound)?.isNotEmpty == true) {
      throw const FormatException(
        'Normal nodes cannot reference other outbounds; use Raw for a complete configuration',
      );
    }
    if (outbound['protocol'] is! String) {
      throw const FormatException('Node protocol is required');
    }
    return copyOutboundMap(outbound)..['tag'] = tag;
  }

  static Map<String, dynamic> _object(Map<String, dynamic> parent, String key) {
    final value = parent[key];
    if (value == null) return parent[key] = <String, dynamic>{};
    if (value is! Map<String, dynamic>) {
      throw FormatException('$key must be an object');
    }
    return parent[key] = Map<String, dynamic>.from(value);
  }

  static List<Map<String, dynamic>> _objects(
    Map<String, dynamic> parent,
    String key,
  ) {
    final value = parent[key] ?? <dynamic>[];
    if (value is! List || value.any((item) => item is! Map<String, dynamic>)) {
      throw FormatException('$key must be an object array');
    }
    return value.cast<Map<String, dynamic>>().toList();
  }

  static XrayInbound _runtimeInbound(RuntimeOptions options) {
    if (options.platform == ConnectionPlatform.windows) {
      return createSocksInbound('${options.socksPort}');
    }
    final linux = options.platform == ConnectionPlatform.linux;
    return createTunInbound(
      gateway: linux ? ['198.18.0.1/15', if (options.ipv6) 'fc00::1/64'] : null,
      dns: linux ? ['8.8.8.8', if (options.ipv6) '2001:4860:4860::8888'] : null,
      autoSystemRoutingTable: linux
          ? ['0.0.0.0/0', if (options.ipv6) '::/0']
          : null,
      autoOutboundsInterface: linux ? options.interfaceName : null,
    );
  }

  static XrayLog _runtimeLog(RuntimeOptions options) {
    final enabled = options.logEnabled && options.logFilesSupported;
    return XrayLog(
      access: enabled ? '${options.sessionDirectory}/access.log' : 'none',
      error: enabled ? '${options.sessionDirectory}/error.log' : 'none',
      logLevel: enabled ? options.logLevel : 'none',
      dnsLog: enabled && options.dnsLog,
      maskAddress: options.maskAddress,
    );
  }

  static XrayPolicySystem _runtimeStatsPolicy() => XrayPolicySystem(
    statsInboundUplink: true,
    statsInboundDownlink: true,
    statsOutboundUplink: false,
    statsOutboundDownlink: false,
  );

  static Map<String, dynamic> _rawRuntimeMap(
    Map<String, dynamic> source,
    RuntimeOptions options,
  ) {
    final config = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    validateLocalDnsNetworkPolicy(
      config,
      ipv6: options.ipv6,
      requiresInterface:
          options.platform == ConnectionPlatform.windows ||
          options.platform == ConnectionPlatform.linux,
    );
    final outbounds = _objects(config, 'outbounds');
    if (outbounds.isEmpty) {
      throw const FormatException('At least one outbound is required');
    }
    final tags = <String>{};
    for (final outbound in outbounds) {
      final tag = outbound['tag'];
      if (tag != null && (tag is! String || !tags.add(tag))) {
        throw const FormatException('Duplicate or invalid outbound tag');
      }
    }
    final inbounds = _objects(config, 'inbounds');
    final inboundTags = <String>{};
    for (final inbound in inbounds) {
      final tag = inbound['tag'];
      if (tag != null && (tag is! String || !inboundTags.add(tag))) {
        throw const FormatException('Duplicate or invalid inbound tag');
      }
      if (tag == 'tunIn') continue;
      if (inbound['protocol'] == 'tun') {
        throw const FormatException('Use the App-managed tunIn tunnel');
      }
      if (portIncludes(inbound['port'], options.metricsPort) ||
          (options.platform == ConnectionPlatform.windows &&
              portIncludes(inbound['port'], options.socksPort))) {
        throw const FormatException(
          'Raw inbound conflicts with an App-managed port',
        );
      }
    }
    inbounds.removeWhere((inbound) => inbound['tag'] == 'tunIn');
    config['inbounds'] = [_runtimeInbound(options).toJson(), ...inbounds];
    final env = _object(config, 'env');
    env['xray.location.asset'] = VpnConstants.datDir;
    env['xray.location.cert'] = VpnConstants.datDir;
    config.remove(
      'geodata',
    ); // App controls installed files, never core-side remote downloads.
    config['log'] = _runtimeLog(options).toJson();
    config['stats'] = <String, dynamic>{};
    config['metrics'] = {'listen': '127.0.0.1:${options.metricsPort}'};
    final policy = _object(config, 'policy');
    final system = _object(policy, 'system');
    system.addAll(_runtimeStatsPolicy().toJson());
    final levels = policy['levels'];
    if (levels is Map<String, dynamic>) {
      for (final level in levels.values) {
        if (level is Map<String, dynamic>) {
          level['statsUserUplink'] = false;
          level['statsUserDownlink'] = false;
        }
      }
    }
    final dns = _object(config, 'dns');
    final queryStrategy = options.ipv6 ? 'UseIP' : 'UseIPv4';
    dns['queryStrategy'] = queryStrategy;
    for (final server in (dns['servers'] as List? ?? [])) {
      if (server is Map<String, dynamic>) {
        server['queryStrategy'] = queryStrategy;
      }
    }
    if (options.bootstrapAddresses.isNotEmpty) {
      final hosts = _object(dns, 'hosts');
      for (final entry in options.bootstrapAddresses.entries) {
        if (entry.value.isEmpty ||
            entry.value.any(
              (ip) =>
                  InternetAddress.tryParse(ip) == null ||
                  (!options.ipv6 &&
                      InternetAddress(ip).type != InternetAddressType.IPv4),
            )) {
          throw const FormatException('Invalid bootstrap address');
        }
        hosts[entry.key] = entry.value;
      }
    }
    _applyOutboundPolicy(outbounds, options, raw: true);
    final routing = _object(config, 'routing');
    final rules = _objects(routing, 'rules');
    if (!options.ipv6) {
      if (tags.contains(ipv6Block)) {
        throw const FormatException('Reserved IPv6 tag conflict');
      }
      outbounds.add(createBlackholeOutbound(tag: ipv6Block).toJson());
      rules.insert(
        0,
        XrayRoutingRule(
          ruleTag: ipv6Block,
          ip: ['::/0'],
          outboundTag: ipv6Block,
        ).toJson(),
      );
    }
    routing['rules'] = rules;
    config['outbounds'] = outbounds;
    return config;
  }

  // Proxy payloads remain maps in both modes; only their App-owned network
  // fields are changed here, without decoding the full config into a model.
  static void _applyOutboundPolicy(
    List<Map<String, dynamic>> outbounds,
    RuntimeOptions options, {
    required bool raw,
  }) {
    for (final outbound in outbounds) {
      if (['blackhole', 'loopback', 'dns'].contains(outbound['protocol'])) {
        continue;
      }
      final stream = _object(outbound, 'streamSettings');
      final sockopt = _object(stream, 'sockopt');
      if (options.platform == ConnectionPlatform.windows ||
          options.platform == ConnectionPlatform.linux) {
        sockopt['interface'] = options.interfaceName;
      } else {
        sockopt.remove('interface');
      }
      if (!raw) {
        sockopt.remove('domainStrategy');
        final settings = outbound['settings'];
        if (settings is Map<String, dynamic>) {
          settings.remove('domainStrategy');
        }
      }
      if (!options.ipv6) {
        for (final address in outboundAddresses(outbound)) {
          final ip = InternetAddress.tryParse(address);
          if (ip?.type == InternetAddressType.IPv6) {
            throw const FormatException('IPv6 is disabled');
          }
          if (raw &&
              ip == null &&
              !options.bootstrapAddresses.containsKey(address)) {
            throw const FormatException(
              'IPv4 bootstrap resolution is required',
            );
          }
        }
        if (raw) {
          sockopt['domainStrategy'] = 'ForceIPv4';
          if (outbound['protocol'] == 'freedom') {
            _object(outbound, 'settings')['domainStrategy'] = 'ForceIPv4';
          }
        }
      }
      if (sockopt.isEmpty) stream.remove('sockopt');
      if (stream.isEmpty) outbound.remove('streamSettings');
    }
  }

  static bool portIncludes(Object? value, int port) {
    if (value == null) return false;
    for (final part in '$value'.split(',')) {
      final ends = part.trim().split('-');
      final first = int.tryParse(ends.first);
      final last = int.tryParse(ends.last);
      if (first != null && last != null && first <= port && port <= last) {
        return true;
      }
    }
    return false;
  }
}

/// Endpoint hosts only, never TLS SNI/HTTP Host; used for pre-start bootstrap
/// resolution when IPv6 is disabled. No query or target dial occurs here.
Iterable<String> outboundAddresses(Map<String, dynamic> outbound) sync* {
  final settings = outbound['settings'];
  if (settings is! Map) {
    if (outbound['protocol'] == 'wireguard') {
      throw const FormatException(
        'WireGuard settings must contain peer endpoints',
      );
    }
    return;
  }
  if (settings['address'] is String) yield settings['address'] as String;
  for (final key in ['servers', 'vnext']) {
    final entries = settings[key];
    if (entries is List) {
      for (final entry in entries) {
        if (entry is Map && entry['address'] is String) {
          yield entry['address'] as String;
        }
      }
    }
  }
  if (outbound['protocol'] == 'wireguard') {
    final peers = settings['peers'];
    if (peers is! List || peers.isEmpty) {
      throw const FormatException('WireGuard peers must contain endpoints');
    }
    final endpointPattern = RegExp(
      r'^(?:\[([^\]]+)\]|([^:\s/?#@\[\]]+)):(\d+)$',
    );
    for (final peer in peers) {
      final endpoint = peer is Map ? peer['endpoint'] : null;
      final match = endpoint is String
          ? endpointPattern.firstMatch(endpoint)
          : null;
      final port = match == null ? null : int.tryParse(match.group(3)!);
      if (match == null ||
          match.end != endpoint.length ||
          port == null ||
          port < 1 ||
          port > 65535) {
        throw const FormatException(
          'WireGuard endpoint must be host:port or [IPv6]:port',
        );
      }
      final ipv6Host = match.group(1);
      if (ipv6Host != null &&
          InternetAddress.tryParse(ipv6Host)?.type !=
              InternetAddressType.IPv6) {
        throw const FormatException(
          'Invalid bracketed WireGuard IPv6 endpoint',
        );
      }
      yield ipv6Host ?? match.group(2)!;
    }
  }
}
