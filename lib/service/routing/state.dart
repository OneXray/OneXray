import 'package:onexray/core/model/xray_json.dart';
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
    )..validate();
  }

  XrayRoutingRule get xrayJson {
    validate();
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

  void validate() {
    if (ruleTag.isNotEmpty && ruleTag.trim().isEmpty) {
      throw const FormatException('ruleTag must be a non-empty string');
    }
    for (final values in [domain, ip]) {
      if (values.any((value) => value.trim().isEmpty)) {
        throw const FormatException(
          'Domain and IP rules must be non-empty strings',
        );
      }
    }
    if (port != null) _validatePort(port!);
    if (network != null) _validateNetwork(network!);
    if (domain.isEmpty && ip.isEmpty && port == null && network == null) {
      throw const FormatException(
        'Routing rule requires at least one non-empty condition',
      );
    }
  }
}

/// The ordinary Custom routing state between UI, Xray models and persistence.
final class RoutingProfileState {
  final int? id;
  final String name;
  final int entryCount;
  final String domainStrategy;
  final List<RoutingRuleState> rules;

  RoutingProfileState({
    this.id,
    required this.name,
    this.entryCount = 1,
    this.domainStrategy = 'AsIs',
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
        xrayJson.dns != null ||
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
    var entryCount = 0;
    final tags = <String>{};
    for (final outbound in outbounds) {
      if (outbound.isEmpty) {
        entryCount++;
        continue;
      }
      if (outbound.keys.any(
            (key) => !const {'tag', 'protocol', 'settings'}.contains(key),
          ) ||
          (outbound['tag'] != 'direct' && outbound['tag'] != 'block') ||
          outbound['protocol'] !=
              (outbound['tag'] == 'direct' ? 'freedom' : 'blackhole') ||
          !tags.add(outbound['tag'] as String) ||
          (outbound.containsKey('settings') &&
              (outbound['settings'] is! Map ||
                  (outbound['settings'] as Map).isNotEmpty))) {
        throw const FormatException('Unsupported Custom routing outbound');
      }
    }
    if (entryCount < 1 || entryCount > 3) {
      throw const FormatException(
        'outbounds must contain 1–3 empty object slots',
      );
    }
    final state = RoutingProfileState(
      id: id,
      name: name,
      entryCount: entryCount,
      domainStrategy: xrayJson.routing?.domainStrategy ?? 'AsIs',
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
    final hasRouting = domainStrategy != 'AsIs' || rules.isNotEmpty;
    return XrayJson(
      outbounds: [
        for (var index = 0; index < entryCount; index++) <String, dynamic>{},
        {'tag': 'direct', 'protocol': 'freedom'},
        {'tag': 'block', 'protocol': 'blackhole'},
      ],
      routing: hasRouting
          ? XrayRouting(
              domainStrategy: domainStrategy == 'AsIs' ? null : domainStrategy,
              rules: rules.isEmpty
                  ? null
                  : [for (final rule in rules) rule.xrayJson],
            )
          : null,
    );
  }

  String encode() => JsonTool.encoder.convert(xrayJson.toJson());

  RoutingProfileState copyWith({
    int? id,
    bool clearId = false,
    String? name,
    int? entryCount,
    String? domainStrategy,
    Iterable<RoutingRuleState>? rules,
  }) => RoutingProfileState(
    id: clearId ? null : id ?? this.id,
    name: name ?? this.name,
    entryCount: entryCount ?? this.entryCount,
    domainStrategy: domainStrategy ?? this.domainStrategy,
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
    if (domainStrategy != 'AsIs' && domainStrategy != 'IPIfNonMatch') {
      throw const FormatException('Unsupported routing.domainStrategy');
    }
    for (final rule in rules) {
      rule.validate();
    }
  }
}

Object? _copyValue(Object? value) =>
    value is List ? List<Object?>.unmodifiable(value) : value;

void _validatePort(Object value) {
  if (value is! int && value is! String) {
    throw const FormatException(
      'port must be a port or comma-separated ranges',
    );
  }
  for (final part in '$value'.split(',')) {
    final text = part.trim();
    final bounds = text.split('-');
    final start = int.tryParse(bounds.first);
    final end = int.tryParse(bounds.last);
    if (!RegExp(r'^\d+(-\d+)?$').hasMatch(text) ||
        bounds.length > 2 ||
        start == null ||
        end == null ||
        start < 1 ||
        end > 65535 ||
        start > end) {
      throw const FormatException('port contains an invalid range');
    }
  }
}

void _validateNetwork(Object value) {
  final values = value is String ? value.split(',') : value;
  if (values is! List ||
      values.isEmpty ||
      values.any((entry) => entry != 'tcp' && entry != 'udp')) {
    throw const FormatException('network must contain only tcp or udp');
  }
}
