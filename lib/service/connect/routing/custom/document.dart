import 'dart:convert';

import 'package:onexray/core/errors/json_diagnostic.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';
import 'package:onexray/service/connect/routing/custom/metadata.dart';

/// External Custom-routing document after import-only metadata is separated.
final class RoutingProfileDocument {
  final RoutingProfileState state;
  final List<Map<String, String>> assets;

  RoutingProfileDocument._(this.state, this.assets);

  factory RoutingProfileDocument.parse(
    String text, {
    int? id,
    String? name,
    bool allowMetadata = true,
  }) {
    final document = _object(jsonDecode(text), const []);
    _onlyKeys(
      document,
      allowMetadata
          ? const {'name', 'outbounds', 'routing', 'geodata', 'dns'}
          : const {'outbounds', 'routing', 'dns'},
      const [],
    );
    final embeddedName = document['name'];
    if (document.containsKey('name') &&
        (embeddedName is! String ||
            embeddedName.trim().isEmpty ||
            embeddedName.trim().runes.length > 32)) {
      throw const JsonDiagnostic(
        'name must contain 1–32 characters',
        path: ['name'],
      );
    }
    if (document.containsKey('geodata')) routingAssets(document['geodata']);
    document.remove('name');
    _checkEditableFields(document);
    try {
      final xrayJson = XrayJson.fromJson(document);
      final assets = [
        for (final asset in xrayJson.geodata?.assets ?? const [])
          {'file': asset.file!, 'url': asset.url!},
      ];
      xrayJson.geodata = null;
      return RoutingProfileDocument._(
        RoutingProfileState.fromXrayJson(
          id: id,
          name: name ?? (embeddedName as String? ?? ''),
          xrayJson: xrayJson,
        ),
        List.unmodifiable(
          assets.map((asset) => Map<String, String>.unmodifiable(asset)),
        ),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid Custom routing configuration');
    }
  }
}

// Do not silently discard fields the ordinary editor cannot represent.
// Field values and rule semantics are validated by libXray when saving.
void _checkEditableFields(Map<String, dynamic> document) {
  if (document.containsKey('dns')) {
    final dns = _object(document['dns'], const ['dns']);
    _onlyKeys(dns, const {'servers'}, const ['dns']);
    final servers = dns['servers'];
    if (servers is! List) {
      throw const JsonDiagnostic(
        'dns.servers must be an array',
        path: ['dns', 'servers'],
      );
    }
    for (var index = 0; index < servers.length; index++) {
      final path = <Object>['dns', 'servers', index];
      _onlyKeys(_object(servers[index], path), const {'tag', 'address'}, path);
    }
  }
  final routing = document.containsKey('routing')
      ? _object(document['routing'], const ['routing'])
      : <String, dynamic>{};
  _onlyKeys(routing, const {'domainStrategy', 'rules'}, const ['routing']);
  final rules = routing.containsKey('rules') ? routing['rules'] : <dynamic>[];
  if (rules is! List) {
    throw const JsonDiagnostic(
      'routing.rules must be an array',
      path: ['routing', 'rules'],
    );
  }
  for (var index = 0; index < rules.length; index++) {
    final path = <Object>['routing', 'rules', index];
    _onlyKeys(_object(rules[index], path), const {
      'ruleTag',
      'domain',
      'ip',
      'port',
      'network',
      'protocol',
      'localOS',
      'balancerTag',
      'outboundTag',
    }, path);
  }
}

Map<String, dynamic> _object(Object? value, List<Object> path) {
  if (value is! Map<String, dynamic>) {
    throw JsonDiagnostic('${_pathLabel(path)} must be an object', path: path);
  }
  return value;
}

void _onlyKeys(
  Map<String, dynamic> value,
  Set<String> allowed,
  List<Object> path,
) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      throw JsonDiagnostic(
        'Unsupported field: ${_pathLabel(path)}.$key',
        path: [...path, key],
      );
    }
  }
}

String _pathLabel(List<Object> path) => path.isEmpty
    ? 'template'
    : path
          .map((part) => part is int ? '[$part]' : '.$part')
          .join()
          .substring(1);
