import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/connect/routing/dns.dart';
import 'package:onexray/core/tools/json.dart';

enum RoutingRuleAction { proxy, direct, block }

/// Editable state for one Custom routing rule.
///
/// It deliberately mirrors only the four conditions and three actions exposed
/// by the ordinary UI. Raw JSON never passes through this state.
final class RoutingRuleState {
  final String ruleTag;
  final List<String> domain;
  final List<String> ip;
  final Object? port;
  final Object? network;
  final RoutingRuleAction action;

  RoutingRuleState({
    this.ruleTag = '',
    Iterable<String> domain = const [],
    Iterable<String> ip = const [],
    Object? port,
    Object? network,
    this.action = RoutingRuleAction.proxy,
  }) : domain = List.unmodifiable(domain),
       ip = List.unmodifiable(ip),
       port = _copyValue(port),
       network = _copyValue(network);

  factory RoutingRuleState.fromXrayJson(XrayRoutingRule rule) {
    if (rule.inboundTag != null) {
      throw const FormatException('Unsupported Custom routing rule field');
    }
    final action = switch ((rule.balancerTag, rule.outboundTag)) {
      ('proxy', null) => RoutingRuleAction.proxy,
      (null, 'direct') => RoutingRuleAction.direct,
      (null, 'block') => RoutingRuleAction.block,
      _ => throw const FormatException(
        'Routing rule must select exactly one supported action',
      ),
    };
    return RoutingRuleState(
      ruleTag: rule.ruleTag ?? '',
      domain: rule.domain ?? const [],
      ip: rule.ip ?? const [],
      port: _copyValue(rule.port),
      network: _copyValue(rule.network),
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
    RoutingRuleAction? action,
  }) => RoutingRuleState(
    ruleTag: ruleTag ?? this.ruleTag,
    domain: domain ?? this.domain,
    ip: ip ?? this.ip,
    port: port ?? this.port,
    network: network ?? this.network,
    action: action ?? this.action,
  );
}

/// The ordinary Custom routing state between UI, Xray models and persistence.
final class RoutingProfileState {
  final int? id;
  final String name;
  final int entryCount;
  final String directDnsAddress;
  final List<RoutingRuleState> rules;

  RoutingProfileState({
    this.id,
    required this.name,
    this.entryCount = 1,
    this.directDnsAddress = RoutingDns.defaultAddress,
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
      throw const FormatException('outbounds must be an array');
    }
    if (outbounds.isEmpty ||
        outbounds.length > 3 ||
        outbounds.any((outbound) => outbound.isNotEmpty)) {
      throw const FormatException(
        'outbounds must contain 1–3 empty object slots',
      );
    }
    final state = RoutingProfileState(
      id: id,
      name: name,
      entryCount: outbounds.length,
      directDnsAddress: _directDnsAddress(xrayJson.dns),
      rules: [
        for (final rule in xrayJson.routing?.rules ?? const [])
          RoutingRuleState.fromXrayJson(rule),
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

  String encode() => JsonTool.encoder.convert(xrayJson.toJson());

  RoutingProfileState copyWith({
    int? id,
    bool clearId = false,
    String? name,
    int? entryCount,
    String? directDnsAddress,
    Iterable<RoutingRuleState>? rules,
  }) => RoutingProfileState(
    id: clearId ? null : id ?? this.id,
    name: name ?? this.name,
    entryCount: entryCount ?? this.entryCount,
    directDnsAddress: directDnsAddress ?? this.directDnsAddress,
    rules: rules ?? this.rules,
  );

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

String _directDnsAddress(XrayDns? dns) {
  if (dns == null) return RoutingDns.defaultAddress;
  final servers = dns.servers;
  if (servers == null || servers.length != 1) {
    throw const FormatException(
      'Custom routing requires one tagged direct DNS server',
    );
  }
  final server = servers
      .where((server) => server.tag == RoutingDns.directTag)
      .firstOrNull;
  if (server == null ||
      server.address == null ||
      server.domains != null ||
      server.skipFallback != null ||
      server.queryStrategy != null) {
    throw const FormatException(
      'Custom DNS supports only app-dns-direct with an address',
    );
  }
  return server.address!;
}

Object? _copyValue(Object? value) =>
    value is List ? List<Object?>.unmodifiable(value) : value;
