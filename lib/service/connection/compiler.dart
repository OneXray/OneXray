import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/connection/runtime_network_policy.dart';
import 'package:onexray/service/routing/custom_template.dart';
import 'package:onexray/service/routing/region_catalog.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/runtime_inbounds.dart';
import 'package:onexray/service/xray/runtime_outbounds.dart';

class ServerSnapshot {
  final int id;
  final int sourceId;
  final String name;
  final String outboundJson;

  ServerSnapshot({
    required this.id,
    required this.sourceId,
    required Map<String, dynamic> outbound,
  }) : name = outboundDisplayName(outbound),
       outboundJson = jsonEncode(outbound);

  factory ServerSnapshot.fromRow(CoreConfigData row) {
    if (row.type != 'outbound') {
      throw const FormatException('A server must be an outbound');
    }
    return ServerSnapshot(
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
  final String assetDirectory;
  final String sessionDirectory;
  final int pingPort;
  final int metricsPort;
  final int socksPort;
  final XrayInboundAccount pingAuth;
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
    required this.assetDirectory,
    required this.sessionDirectory,
    required this.pingPort,
    required this.metricsPort,
    required this.socksPort,
    required this.pingAuth,
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
    for (final port in [pingPort, metricsPort, socksPort]) {
      if (port < 1 || port > 65535) {
        throw const FormatException('Invalid runtime port');
      }
    }
    if ({pingPort, metricsPort, socksPort}.length != 3 || !pingAuth.isValid) {
      throw const FormatException('Runtime ports/auth are invalid');
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
  final String settingsJson;
  final List<ServerSnapshot> entries;
  final ServerSnapshot? finalExit;
  final Map<String, int> nodeTags;

  /// Runtime rule identity -> original array position/name or Smart reason key.
  final Map<String, ({int? index, String name})> ruleTags;
  final String assetDirectory;

  CompiledConnection({
    required this.xrayJson,
    required this.settingsJson,
    required Iterable<ServerSnapshot> entries,
    required this.finalExit,
    required Map<String, int> nodeTags,
    required Map<String, ({int? index, String name})> ruleTags,
    required this.assetDirectory,
  }) : entries = List.unmodifiable(entries),
       nodeTags = Map.unmodifiable(nodeTags),
       ruleTags = Map.unmodifiable(ruleTags);

  Map<String, dynamic> get config =>
      jsonDecode(xrayJson) as Map<String, dynamic>;
}

/// Pure value compilation. Never opens a database, edits an asset, allocates a
/// port or starts Xray. Runtime files and successful commits belong to P3.
class ConnectionCompiler {
  static Map<String, dynamic> parseRawJson(String text) {
    final value = jsonDecode(text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Raw configuration must be an object');
    }
    return value;
  }

  /// Compare editor drafts through the same runtime overrides as real Raw plans.
  /// The caller supplies identical options for both drafts; no files are written.
  static Map<String, dynamic> rawSemanticJson(
    String text,
    RuntimeOptions options,
  ) {
    final value = parseRawJson(text)..remove('name');
    return _runtimeMap(value, options, raw: true);
  }

  static const dnsProxy = 'app-dns-proxy';
  static const dnsDirect = 'app-dns-direct';
  static const dnsOutbound = 'dnsOut';
  static const ipv6Block = 'app-ipv6-block';

  /// The editor and runtime share these exact built-in rules and their order.
  static List<Map<String, dynamic>> smartRules(
    SmartRoutingSettings smart,
    RegionCatalog regions,
  ) {
    final rules = <Map<String, dynamic>>[];
    void add(String reason, Map<String, dynamic> fields) {
      rules.add({'ruleTag': 'app-smart-$reason', ...fields});
    }

    if (smart.blockAds) {
      add('ads', {
        'domain': ['geosite:CATEGORY-ADS-ALL'],
        'outboundTag': 'block',
      });
    }
    if (smart.directPrivate) {
      add('private-domain', {
        'domain': ['geosite:PRIVATE'],
        'outboundTag': 'direct',
      });
      add('private-ip', {
        'ip': ['geoip:PRIVATE'],
        'outboundTag': 'direct',
      });
    }
    if (smart.directApple) {
      add('apple', {
        'domain': ['geosite:APPLE'],
        'outboundTag': 'direct',
      });
    }
    final domains = regions.domainRules(smart.directRegions);
    final ips = regions.ipRules(smart.directRegions);
    if (domains.isNotEmpty) {
      add('regions-domain', {'domain': domains, 'outboundTag': 'direct'});
    }
    if (ips.isNotEmpty) {
      add('regions-ip', {'ip': ips, 'outboundTag': 'direct'});
    }
    return rules;
  }

  static CompiledConnection compile({
    required ConnectionSettings settings,
    required List<ServerSnapshot> entries,
    ServerSnapshot? finalExit,
    Map<String, dynamic>? raw,
    CustomRoutingTemplate? custom,
    required RegionCatalog regions,
    required RuntimeOptions options,
  }) {
    final nodeTags = <String, int>{};
    final ruleTags = <String, ({int? index, String name})>{};
    late final Map<String, dynamic> config;
    if (settings.expert) {
      if (raw == null || entries.isNotEmpty || finalExit != null) {
        throw const FormatException(
          'Raw configuration is required without normal nodes',
        );
      }
      config = _runtimeMap(raw, options, raw: true);
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
      final rules = <Map<String, dynamic>>[];
      var domainStrategy = 'AsIs';
      if (settings.trafficMode == TrafficMode.smart) {
        final smart = settings.smart;
        domainStrategy = smart.resolveIpOnNoMatch ? 'IPIfNonMatch' : 'AsIs';
        for (final rule in smartRules(smart, regions)) {
          final tag = rule['ruleTag'] as String;
          ruleTags[tag] = (
            index: null,
            name: tag.substring('app-smart-'.length),
          );
          rules.add(rule);
        }
      } else if (settings.trafficMode == TrafficMode.custom) {
        domainStrategy = custom!.domainStrategy;
        for (final (index, rule) in custom.rules.indexed) {
          final tag = 'app-custom-$index';
          ruleTags[tag] = (
            index: index,
            name: rule['ruleTag'] as String? ?? '',
          );
          rules.add({...rule, 'ruleTag': tag});
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
      outbounds.addAll([
        createFreedomOutboundMap(
          tag: 'direct',
          interfaceName:
              options.platform == ConnectionPlatform.windows ||
                  options.platform == ConnectionPlatform.linux
              ? options.interfaceName
              : null,
        ),
        createBlackholeOutboundMap(tag: 'block'),
        createDnsOutboundMap(tag: dnsOutbound, dialerProxy: 'direct'),
      ]);
      final directDomains = <String>{};
      if (settings.trafficMode != TrafficMode.smart ||
          settings.smart.directDns) {
        for (final rule in rules.where(
          (rule) => rule['outboundTag'] == 'direct',
        )) {
          directDomains.addAll((rule['domain'] as List?)?.cast<String>() ?? []);
        }
      }
      final source = XrayJson.fromJson({
        'outbounds': outbounds,
        'observatory': {'subjectSelector': <String>[]},
        'dns': {
          'servers': [
            {'address': '8.8.8.8', 'tag': dnsProxy},
            {
              'address': '8.8.8.8',
              'tag': dnsDirect,
              'domains': directDomains.toList(),
              'skipFallback': true,
            },
          ],
        },
        'routing': {
          'domainStrategy': domainStrategy,
          'balancers': [
            {
              'tag': 'proxy',
              'selector': selector,
              'strategy': {'type': 'roundRobin'},
              'fallbackTag': 'block',
            },
          ],
          'rules': [
            {
              'ruleTag': 'app-default',
              'inboundTag': ['pingIn', dnsProxy],
              'balancerTag': 'proxy',
            },
            {
              'ruleTag': 'app-direct-dns',
              'inboundTag': [dnsDirect],
              'outboundTag': 'direct',
            },
            {
              'ruleTag': 'app-tunnel-dns',
              'inboundTag': ['tunIn'],
              'port': '53',
              'outboundTag': dnsOutbound,
            },
            {
              'ruleTag': 'app-tunnel-dot',
              'inboundTag': ['tunIn'],
              'port': '853',
              'balancerTag': 'proxy',
            },
            ...rules,
          ],
        },
      });
      final runtime = _runtimeMap(source.toJson(), options, raw: false);
      config = XrayJson.fromJson(runtime).toJson();
    }
    return CompiledConnection(
      xrayJson: jsonEncode(config),
      settingsJson: jsonEncode(settings.toJson()),
      entries: entries,
      finalExit: finalExit,
      nodeTags: nodeTags,
      ruleTags: ruleTags,
      assetDirectory: options.assetDirectory,
    );
  }

  static Map<String, dynamic> _node(ServerSnapshot node, String tag) {
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

  static Map<String, dynamic> _runtimeMap(
    Map<String, dynamic> source,
    RuntimeOptions options, {
    required bool raw,
  }) {
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
      if (tag == 'tunIn' || tag == 'pingIn') continue;
      if (inbound['protocol'] == 'tun') {
        throw const FormatException('Use the App-managed tunIn tunnel');
      }
      if (portIncludes(inbound['port'], options.pingPort) ||
          portIncludes(inbound['port'], options.metricsPort) ||
          (options.platform == ConnectionPlatform.windows &&
              portIncludes(inbound['port'], options.socksPort))) {
        throw const FormatException(
          'Raw inbound conflicts with an App-managed port',
        );
      }
    }
    inbounds.removeWhere(
      (inbound) => inbound['tag'] == 'tunIn' || inbound['tag'] == 'pingIn',
    );
    final tun = options.platform == ConnectionPlatform.windows
        ? createSocksInboundMap('${options.socksPort}')
        : createTunInboundMap();
    if (options.platform == ConnectionPlatform.linux) {
      (tun['settings'] as Map<String, dynamic>).addAll({
        'gateway': ['198.18.0.1/15', if (options.ipv6) 'fc00::1/64'],
        'dns': ['8.8.8.8', if (options.ipv6) '2001:4860:4860::8888'],
        'autoSystemRoutingTable': ['0.0.0.0/0', if (options.ipv6) '::/0'],
        'autoOutboundsInterface': options.interfaceName,
      });
    }
    config['inbounds'] = [
      tun,
      ...inbounds,
      createPingInboundMap(port: '${options.pingPort}', auth: options.pingAuth),
    ];
    final env = _object(config, 'env');
    env['xray.location.asset'] = options.assetDirectory;
    env['xray.location.cert'] = options.assetDirectory;
    config.remove(
      'geodata',
    ); // App controls installed files, never core-side remote downloads.
    final log = options.logEnabled && options.logFilesSupported;
    config['log'] = {
      'access': log ? '${options.sessionDirectory}/access.log' : 'none',
      'error': log ? '${options.sessionDirectory}/error.log' : 'none',
      'loglevel': log ? options.logLevel : 'none',
      'dnsLog': log && options.dnsLog,
      'maskAddress': options.maskAddress,
    };
    config['stats'] = <String, dynamic>{};
    config['metrics'] = {'listen': '127.0.0.1:${options.metricsPort}'};
    final policy = _object(config, 'policy');
    final system = _object(policy, 'system');
    system.addAll({
      'statsInboundUplink': true,
      'statsInboundDownlink': true,
      'statsOutboundUplink': false,
      'statsOutboundDownlink': false,
    });
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
    if (raw) dns['queryStrategy'] = queryStrategy;
    for (final server in (dns['servers'] as List? ?? [])) {
      if (server is Map<String, dynamic>) {
        server['queryStrategy'] = queryStrategy;
      }
    }
    if (raw && options.bootstrapAddresses.isNotEmpty) {
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
    final routing = _object(config, 'routing');
    final rules = _objects(routing, 'rules');
    if (raw) {
      const pingRule = 'app-ping';
      if (rules.any((rule) => rule['ruleTag'] == pingRule)) {
        throw const FormatException('Reserved ping rule conflict');
      }
      var firstTag = outbounds.first['tag'] as String?;
      if (firstTag == null || firstTag.isEmpty) {
        firstTag = 'app-raw-default';
        if (tags.contains(firstTag)) {
          throw const FormatException('Reserved default tag conflict');
        }
        outbounds.first['tag'] = firstTag;
      }
      rules.insert(0, {
        'ruleTag': pingRule,
        'inboundTag': ['pingIn'],
        'outboundTag': firstTag,
      });
    }
    // Global IPv6 policy must precede even the App-owned Raw ping rule.
    if (!options.ipv6) {
      var blockTag = 'block';
      if (raw) {
        if (tags.contains(ipv6Block)) {
          throw const FormatException('Reserved IPv6 tag conflict');
        }
        blockTag = ipv6Block;
        outbounds.add({'tag': blockTag, 'protocol': 'blackhole'});
      }
      rules.insert(0, {
        'ruleTag': ipv6Block,
        'ip': ['::/0'],
        'outboundTag': blockTag,
      });
    }
    routing['rules'] = rules;
    config['outbounds'] = outbounds;
    return config;
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
