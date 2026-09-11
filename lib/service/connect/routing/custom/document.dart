import 'dart:convert';

import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';
import 'package:onexray/service/advanced/xray/geodata/model.dart';

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
    final document = _object(jsonDecode(text), 'template');
    _onlyKeys(
      document,
      allowMetadata
          ? const {'name', 'outbounds', 'routing', 'geodata', 'dns'}
          : const {'outbounds', 'routing', 'dns'},
      'template',
    );
    final embeddedName = document['name'];
    if (document.containsKey('name') &&
        (embeddedName is! String ||
            embeddedName.trim().isEmpty ||
            embeddedName.trim().runes.length > 32)) {
      throw const FormatException('name must contain 1–32 characters');
    }
    if (document.containsKey('geodata')) _checkAssets(document['geodata']);
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
    final dns = _object(document['dns'], 'dns');
    _onlyKeys(dns, const {'servers'}, 'dns');
    final servers = dns['servers'];
    if (servers is! List) {
      throw const FormatException('dns.servers must be an array');
    }
    for (var index = 0; index < servers.length; index++) {
      _onlyKeys(_object(servers[index], 'dns.servers[$index]'), const {
        'tag',
        'address',
      }, 'dns.servers[$index]');
    }
  }
  final routing = document.containsKey('routing')
      ? _object(document['routing'], 'routing')
      : <String, dynamic>{};
  _onlyKeys(routing, const {'domainStrategy', 'rules'}, 'routing');
  final rules = routing.containsKey('rules') ? routing['rules'] : <dynamic>[];
  if (rules is! List) {
    throw const FormatException('routing.rules must be an array');
  }
  for (var index = 0; index < rules.length; index++) {
    _onlyKeys(_object(rules[index], 'routing.rules[$index]'), const {
      'ruleTag',
      'domain',
      'ip',
      'port',
      'network',
      'balancerTag',
      'outboundTag',
    }, 'routing.rules[$index]');
  }
}

Map<String, dynamic> _object(Object? value, String path) {
  if (value is! Map<String, dynamic>) {
    throw FormatException('$path must be an object');
  }
  return value;
}

void _onlyKeys(Map<String, dynamic> value, Set<String> allowed, String path) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      throw FormatException('Unsupported field: $path.$key');
    }
  }
}

void _checkAssets(Object? value) {
  final geodata = _object(value, 'geodata');
  _onlyKeys(geodata, const {'assets'}, 'geodata');
  final assets = geodata['assets'];
  if (assets is! List) {
    throw const FormatException('geodata.assets must be an array');
  }
  final names = <String>{};
  for (var index = 0; index < assets.length; index++) {
    final path = 'geodata.assets[$index]';
    final asset = _object(assets[index], path);
    _onlyKeys(asset, const {'file', 'url'}, path);
    final file = asset['file'];
    if (file is! String) {
      throw FormatException('$path.file must be a safe custom .dat filename');
    }
    GeoDataInput.referenceFileName(file);
    if (!names.add(file.toLowerCase())) {
      throw FormatException('$path duplicates a geodata filename');
    }
    final url = asset['url'];
    if (url is! String) {
      throw FormatException('$path.url must be an HTTPS URL');
    }
    GeoDataInput.httpsUri(url);
  }
}
