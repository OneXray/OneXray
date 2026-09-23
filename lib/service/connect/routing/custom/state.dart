import 'package:onexray/core/errors/json_diagnostic.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/connect/routing/dns.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/shared/xray/fake_dns.dart';
import 'package:onexray/service/connect/routing/custom/configuration.dart';

enum RoutingRuleAction { proxy, direct, block }

/// Editable state for one Custom routing rule.
///
/// It deliberately mirrors only the conditions and three actions exposed
/// by the ordinary UI. Raw JSON never passes through this state.
final class RoutingRuleState {
  final String ruleTag;
  final List<String> domain;
  final List<String> ip;
  final Object? port;
  final Object? network;
  final List<String> protocol;
  final List<String> localOS;
  final RoutingRuleAction action;

  RoutingRuleState({
    this.ruleTag = '',
    Iterable<String> domain = const [],
    Iterable<String> ip = const [],
    Object? port,
    Object? network,
    Iterable<String> protocol = const [],
    Iterable<String> localOS = const [],
    this.action = RoutingRuleAction.proxy,
  }) : domain = List.unmodifiable(domain),
       ip = List.unmodifiable(ip),
       port = _copyValue(port),
       protocol = List.unmodifiable(protocol),
       localOS = List.unmodifiable(localOS),
       network = _copyValue(network);

  factory RoutingRuleState.fromXrayJson(
    XrayRoutingRule rule, {
    List<Object>? path,
  }) {
    if (rule.inboundTag != null) {
      throw JsonDiagnostic(
        'Unsupported Custom routing rule field',
        path: path == null ? null : [...path, 'inboundTag'],
      );
    }
    final action = switch ((rule.balancerTag, rule.outboundTag)) {
      ('proxy', null) => RoutingRuleAction.proxy,
      (null, 'direct') => RoutingRuleAction.direct,
      (null, 'block') => RoutingRuleAction.block,
      _ => throw JsonDiagnostic(
        'Routing rule must select exactly one supported action',
        path: path,
      ),
    };
    return RoutingRuleState(
      ruleTag: rule.ruleTag ?? '',
      domain: rule.domain ?? const [],
      ip: rule.ip ?? const [],
      port: _copyValue(rule.port),
      network: _copyValue(rule.network),
      protocol: rule.protocol ?? const [],
      localOS: rule.localOS ?? const [],
      action: action,
    );
  }

  XrayRoutingRule get xrayJson {
    return XrayRoutingRule(
      ruleTag: ruleTag.isEmpty ? null : ruleTag,
      domain: domain.isEmpty ? null : List.of(domain),
      ip: ip.isEmpty ? null : List.of(ip),
      port: _copyValue(port),
      network: _copyValue(network),
      protocol: protocol.isEmpty ? null : List.of(protocol),
      localOS: localOS.isEmpty ? null : List.of(localOS),
      balancerTag: action == RoutingRuleAction.proxy ? 'proxy' : null,
      outboundTag: action == RoutingRuleAction.proxy ? null : action.name,
    );
  }

  Map<String, dynamic> toJson() => xrayJson.toJson();

  RoutingRuleState copyWith({
    String? ruleTag,
    Iterable<String>? domain,
    Iterable<String>? ip,
    Object? port,
    Object? network,
    Iterable<String>? protocol,
    Iterable<String>? localOS,
    RoutingRuleAction? action,
  }) => RoutingRuleState(
    ruleTag: ruleTag ?? this.ruleTag,
    domain: domain ?? this.domain,
    ip: ip ?? this.ip,
    port: port ?? this.port,
    network: network ?? this.network,
    protocol: protocol ?? this.protocol,
    localOS: localOS ?? this.localOS,
    action: action ?? this.action,
  );
}

/// The ordinary Custom routing state between UI, Xray models and persistence.
final class RoutingProfileState implements RoutingConfiguration {
  @override
  final int? id;
  @override
  final String name;
  @override
  final int entryCount;
  final String directDnsAddress;
  final bool fakeDns;
  final List<RoutingRuleState> rules;

  RoutingProfileState({
    this.id,
    required this.name,
    this.entryCount = 1,
    this.directDnsAddress = RoutingDns.defaultAddress,
    this.fakeDns = false,
    Iterable<RoutingRuleState> rules = const [],
  }) : rules = List.unmodifiable(rules);

  factory RoutingProfileState.fromXrayJson({
    int? id,
    required String name,
    required XrayJson xrayJson,
  }) {
    if (xrayJson.env != null ||
        xrayJson.geodata != null ||
        xrayJson.log != null ||
        xrayJson.fakedns != null ||
        xrayJson.inbounds != null ||
        xrayJson.policy != null ||
        xrayJson.stats != null ||
        xrayJson.metrics != null ||
        xrayJson.observatory != null ||
        xrayJson.routing?.balancers != null) {
      throw const FormatException('Unsupported Custom routing field');
    }
    final outbounds = xrayJson.outbounds;
    if (outbounds == null) {
      throw const JsonDiagnostic(
        'outbounds must be an array',
        path: ['outbounds'],
      );
    }
    if (outbounds.isEmpty ||
        outbounds.length > 3 ||
        outbounds.any((outbound) => outbound.isNotEmpty)) {
      throw const JsonDiagnostic(
        'outbounds must contain 1–3 empty object slots',
        path: ['outbounds'],
      );
    }
    final dns = _dnsSettings(xrayJson.dns);
    final state = RoutingProfileState(
      id: id,
      name: name,
      entryCount: outbounds.length,
      directDnsAddress: dns.directAddress,
      fakeDns: dns.fakeDns,
      rules: [
        for (final (index, rule)
            in (xrayJson.routing?.rules ?? const <XrayRoutingRule>[]).indexed)
          RoutingRuleState.fromXrayJson(
            rule,
            path: ['routing', 'rules', index],
          ),
      ],
    );
    state.validate();
    return state;
  }

  XrayJson get xrayJson {
    validate();
    return XrayJson(
      dns: XrayDns(
        servers: [
          XrayDnsServer(
            tag: RoutingDns.directTag,
            address: directDnsAddress.trim(),
          ),
          if (fakeDns)
            XrayDnsServer(tag: FakeDns.tag, address: FakeDns.address),
        ],
      ),
      outbounds: [
        for (var index = 0; index < entryCount; index++) <String, dynamic>{},
      ],
      routing: XrayRouting(
        domainStrategy: 'IPIfNonMatch',
        rules: rules.isEmpty ? null : [for (final rule in rules) rule.xrayJson],
      ),
    );
  }

  @override
  String encode() => JsonTool.encoder.convert(xrayJson.toJson());

  @override
  bool get advanced => false;

  @override
  int get ruleCount => rules.length;

  @override
  Map<String, dynamic> toJson() => xrayJson.toJson();

  @override
  RoutingProfileState copyWith({
    int? id,
    bool clearId = false,
    String? name,
    int? entryCount,
    String? directDnsAddress,
    bool? fakeDns,
    Iterable<RoutingRuleState>? rules,
  }) => RoutingProfileState(
    id: clearId ? null : id ?? this.id,
    name: name ?? this.name,
    entryCount: entryCount ?? this.entryCount,
    directDnsAddress: directDnsAddress ?? this.directDnsAddress,
    fakeDns: fakeDns ?? this.fakeDns,
    rules: rules ?? this.rules,
  );

  @override
  void validate() {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty && trimmedName.runes.length > 32) {
      throw const FormatException(
        'Custom route name must contain at most 32 characters',
      );
    }
    if (entryCount < 1 || entryCount > 3) {
      throw const FormatException('Custom routing requires 1–3 entry nodes');
    }
  }
}

({String directAddress, bool fakeDns}) _dnsSettings(XrayDns? dns) {
  if (dns == null) {
    return (directAddress: RoutingDns.defaultAddress, fakeDns: false);
  }
  final servers = dns.servers;
  if (servers == null) {
    throw const JsonDiagnostic(
      'Custom routing requires one tagged direct DNS server',
      path: ['dns', 'servers'],
    );
  }
  final direct = servers
      .where((server) => server.tag == RoutingDns.directTag)
      .toList();
  final fake = servers.where((server) => server.tag == FakeDns.tag).toList();
  if (direct.length != 1 ||
      fake.length > 1 ||
      servers.length != direct.length + fake.length ||
      servers.any(
        (server) =>
            server.address == null ||
            server.domains != null ||
            server.skipFallback != null ||
            server.queryStrategy != null,
      ) ||
      (fake.isNotEmpty && !FakeDns.isAddress(fake.single.address))) {
    throw const JsonDiagnostic(
      'Custom DNS supports app-dns-direct and an optional app-dns-fake server',
      path: ['dns', 'servers'],
    );
  }
  return (directAddress: direct.single.address!, fakeDns: fake.isNotEmpty);
}

Object? _copyValue(Object? value) =>
    value is List ? List<Object?>.unmodifiable(value) : value;
