import 'dart:convert';

import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/connect/routing/custom/configuration.dart';
import 'package:onexray/service/connect/routing/custom/metadata.dart';
import 'package:onexray/service/shared/xray/runtime_outbounds.dart';

/// Node-free JSON template. No ordinary model round-trip or implicit DNS rules.
final class AdvancedRoutingProfile implements RoutingConfiguration {
  static const defaultText = '''{
  "outbounds": [
    {},
    {
      "tag": "dnsOut",
      "protocol": "dns",
      "settings": {
        "rules": [
          {"action": "hijack", "qType": "1,28"},
          {"action": "drop"}
        ]
      }
    }
  ],
  "inbounds": [
    {
      "tag": "tunIn",
      "sniffing": {
        "enabled": true,
        "routeOnly": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "dns": {
    "servers": [{"tag": "dns-proxy", "address": "8.8.8.8"}]
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"ruleTag": "Proxy DNS", "inboundTag": ["dns-proxy"], "balancerTag": "proxy"},
      {"ruleTag": "Tunnel DNS", "inboundTag": ["tunIn"], "port": 53, "outboundTag": "dnsOut"},
      {"ruleTag": "DNS over TLS", "inboundTag": ["tunIn"], "port": 853, "balancerTag": "proxy"}
    ]
  }
}''';
  @override
  final int? id;
  @override
  final String name;
  @override
  final int entryCount;
  final Map<String, dynamic> _json;

  AdvancedRoutingProfile._(this.id, this.name, this.entryCount, this._json);

  @override
  bool get advanced => true;
  @override
  int get ruleCount =>
      ((_json['routing'] as Map?)?['rules'] as List?)?.length ?? 0;
  @override
  Map<String, dynamic> toJson() => JsonTool.copyMap(_json);
  @override
  String encode() => JsonTool.encoder.convert(_json);
  @override
  void validate() {
    if (name.trim().runes.length > 32) {
      throw const FormatException(
        'Custom route name must contain at most 32 characters',
      );
    }
  }

  @override
  AdvancedRoutingProfile copyWith({
    int? id,
    bool clearId = false,
    String? name,
  }) => AdvancedRoutingProfile._(
    clearId ? null : id ?? this.id,
    name ?? this.name,
    entryCount,
    _json,
  )..validate();

  /// The same composition is used with real nodes or local validation slots.
  Map<String, dynamic> fillSlots(List<Map<String, dynamic>> entries) {
    final json = toJson();
    json['outbounds'] = [
      ...entries.map(JsonTool.copyMap),
      ...(json['outbounds'] as List).skip(entryCount),
      createFreedomOutbound(tag: 'direct').toJson(),
      createBlackholeOutbound(tag: 'block').toJson(),
    ];
    final routing =
        json['routing'] as Map<String, dynamic>? ?? <String, dynamic>{};
    routing['balancers'] = [
      XrayBalancer(
        tag: 'proxy',
        selector: [for (final entry in entries) entry['tag'] as String],
        strategy: XrayBalancingStrategy(type: 'roundRobin'),
        fallbackTag: 'direct',
      ).toJson(),
    ];
    json['routing'] = routing;
    json['observatory'] = XrayObservatory(subjectSelector: []).toJson();
    return json;
  }
}

final class AdvancedRoutingDocument {
  final AdvancedRoutingProfile state;
  final List<Map<String, String>> assets;
  AdvancedRoutingDocument._(this.state, this.assets);

  factory AdvancedRoutingDocument.parse(
    String text, {
    int? id,
    String? name,
    bool allowMetadata = true,
  }) {
    final json = _object(jsonDecode(text), 'template');
    _keys(json, {
      'outbounds',
      'inbounds',
      'dns',
      'routing',
      'fakedns',
      if (allowMetadata) ...['name', 'geodata'],
    }, 'template');
    final hasName = json.containsKey('name');
    final embeddedName = json.remove('name');
    if (hasName &&
        (embeddedName is! String ||
            embeddedName.trim().isEmpty ||
            embeddedName.trim().runes.length > 32)) {
      throw const FormatException('name must contain 1–32 characters');
    }
    final assets = json.containsKey('geodata')
        ? routingAssets(json.remove('geodata'))
        : <Map<String, String>>[];
    final outbounds = _objects(json['outbounds'], 'outbounds');
    final count = outbounds.takeWhile((value) => value.isEmpty).length;
    if (count < 1 ||
        count > 3 ||
        outbounds.skip(count).any((value) => value.isEmpty)) {
      throw const FormatException(
        'outbounds must start with 1–3 empty entry slots',
      );
    }
    final tags = <String>{};
    for (final (index, outbound) in outbounds.indexed.skip(count)) {
      final path = 'outbounds[$index]';
      _keys(outbound, {'tag', 'protocol', 'settings', 'streamSettings'}, path);
      _definition(outbound['tag'], path, tags);
      if (!const {
        'freedom',
        'blackhole',
        'dns',
      }.contains(outbound['protocol'])) {
        throw FormatException('$path supports only freedom, blackhole and dns');
      }
      final stream = outbound['streamSettings'];
      if (stream != null) {
        final map = _object(stream, '$path.streamSettings');
        _keys(map, {'sockopt'}, '$path.streamSettings');
        if (map['sockopt'] != null) {
          final sockopt = _object(
            map['sockopt'],
            '$path.streamSettings.sockopt',
          );
          _keys(sockopt, {'dialerProxy'}, '$path.streamSettings.sockopt');
          _outboundReference(
            sockopt['dialerProxy'],
            '$path.streamSettings.sockopt.dialerProxy',
          );
        }
      }
    }
    var tunSeen = false;
    if (json.containsKey('inbounds')) {
      for (final (index, inbound) in _objects(
        json['inbounds'],
        'inbounds',
      ).indexed) {
        final path = 'inbounds[$index]';
        if (inbound['tag'] == 'tunIn') {
          if (tunSeen) {
            throw const FormatException(
              'Only one tunIn placeholder is allowed',
            );
          }
          tunSeen = true;
          _keys(inbound, {'tag', 'sniffing'}, path);
        } else {
          _keys(inbound, {
            'tag',
            'protocol',
            'listen',
            'port',
            'settings',
            'sniffing',
          }, path);
          _definition(inbound['tag'], path, tags);
          final protocol = inbound['protocol'];
          if (!const {'socks', 'http', 'tunnel'}.contains(protocol)) {
            throw FormatException('$path supports only socks, http and tunnel');
          }
          if (inbound.containsKey('settings')) {
            _keys(
              _object(inbound['settings'], '$path.settings'),
              switch (protocol) {
                'socks' => {'auth', 'users', 'accounts', 'udp'},
                'http' => {'users', 'accounts'},
                _ => {'rewriteAddress', 'rewritePort', 'allowedNetwork'},
              },
              '$path.settings',
            );
          }
        }
        if (inbound.containsKey('sniffing')) {
          _keys(_object(inbound['sniffing'], '$path.sniffing'), {
            'enabled',
            'routeOnly',
            'destOverride',
            'metadataOnly',
            'domainsExcluded',
            'ipsExcluded',
          }, '$path.sniffing');
        }
      }
    }
    if (json.containsKey('dns')) {
      final dns = _object(json['dns'], 'dns');
      if (dns.containsKey('queryStrategy')) _managed('dns.queryStrategy');
      if (dns.containsKey('tag')) _definition(dns['tag'], 'dns', <String>{});
      if (dns['servers'] is List) {
        for (final (index, server) in (dns['servers'] as List).indexed) {
          if (server is! Map) continue;
          if (server.containsKey('queryStrategy')) {
            _managed('dns.servers[$index].queryStrategy');
          }
          if (server.containsKey('tag')) {
            _definition(server['tag'], 'dns.servers[$index]', <String>{});
          }
        }
      }
    }
    if (json.containsKey('routing')) {
      final routing = _object(json['routing'], 'routing');
      _keys(routing, {'domainStrategy', 'rules'}, 'routing');
      if (routing.containsKey('rules')) {
        for (final (index, rule) in _objects(
          routing['rules'],
          'routing.rules',
        ).indexed) {
          final path = 'routing.rules[$index]';
          _keys(rule, {
            'ruleTag',
            'domain',
            'ip',
            'port',
            'network',
            'protocol',
            'localOS',
            'inboundTag',
            'localIP',
            'localPort',
            'balancerTag',
            'outboundTag',
          }, path);
          if (rule.containsKey('balancerTag') &&
              rule['balancerTag'] != 'proxy') {
            throw FormatException('$path.balancerTag must use proxy');
          }
          _outboundReference(rule['outboundTag'], '$path.outboundTag');
          final inboundTags = rule['inboundTag'];
          if (inboundTags is List) {
            for (final tag in inboundTags) {
              if (tag is String && _internal(tag)) _managed('$path.inboundTag');
            }
          }
        }
      }
    }
    final state = AdvancedRoutingProfile._(
      id,
      name ?? embeddedName as String? ?? '',
      count,
      json,
    )..validate();
    return AdvancedRoutingDocument._(state, List.unmodifiable(assets));
  }
}

Map<String, dynamic> _object(Object? value, String path) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$path must be an object');
  }
  return value;
}

List<Map<String, dynamic>> _objects(Object? value, String path) {
  if (value is! List) throw FormatException('$path must be an array');
  return [for (final item in value) _object(item, path)];
}

void _keys(Map<String, dynamic> value, Set<String> allowed, String path) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      throw FormatException('Unsupported or App-managed field: $path.$key');
    }
  }
}

bool _internal(String tag) =>
    tag.startsWith('app-entry-') || tag.startsWith('app-exit-');
Never _managed(String path) =>
    throw FormatException('$path is managed by OneXray; use App settings');
void _definition(Object? tag, String path, Set<String> tags) {
  if (tag is! String || tag.isEmpty) {
    throw FormatException('$path requires a tag');
  }
  if (_internal(tag) ||
      const {'proxy', 'direct', 'block', 'tunIn'}.contains(tag)) {
    _managed('$path.tag');
  }
  if (!tags.add(tag)) throw FormatException('Duplicate tag: $tag');
}

void _outboundReference(Object? tag, String path) {
  if (tag is String && (_internal(tag) || tag == 'proxy')) {
    throw FormatException(
      '$path cannot reference an internal node or the proxy balancer; use balancerTag: proxy',
    );
  }
}
