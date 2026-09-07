import 'dart:convert';

import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';
import 'package:path/path.dart' as p;

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
          ? const {'name', 'outbounds', 'routing', 'geodata'}
          : const {'outbounds', 'routing'},
      'template',
    );
    final embeddedName = document['name'];
    if (document.containsKey('name') &&
        (embeddedName is! String ||
            embeddedName.trim().isEmpty ||
            embeddedName.trim().runes.length > 32)) {
      throw const FormatException('name must contain 1–32 characters');
    }
    if (document.containsKey('geodata')) _readAssets(document['geodata']);
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

List<Map<String, String>> _readAssets(Object? value) {
  final geodata = _object(value, 'geodata');
  _onlyKeys(geodata, const {'assets'}, 'geodata');
  final assets = geodata['assets'];
  if (assets is! List) {
    throw const FormatException('geodata.assets must be an array');
  }
  final result = <Map<String, String>>[];
  final names = <String>{};
  for (var index = 0; index < assets.length; index++) {
    final path = 'geodata.assets[$index]';
    final asset = _object(assets[index], path);
    _onlyKeys(asset, const {'file', 'url'}, path);
    final file = asset['file'];
    if (file is! String ||
        file.length <= 4 ||
        file != file.trim() ||
        !file.toLowerCase().endsWith('.dat') ||
        p.posix.basename(file) != file ||
        p.windows.basename(file) != file ||
        file.contains(RegExp(r'[\\/:*?"<>|\x00-\x1f\x7f]')) ||
        RegExp(
          r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])\.',
          caseSensitive: false,
        ).hasMatch(file) ||
        const {'geosite.dat', 'geoip.dat'}.contains(file.toLowerCase())) {
      throw FormatException('$path.file must be a safe custom .dat filename');
    }
    if (!names.add(file.toLowerCase())) {
      throw FormatException('$path duplicates a geodata filename');
    }
    final url = asset['url'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (url is! String ||
        url.contains(RegExp(r'\s')) ||
        uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw FormatException(
        '$path.url must be an HTTPS URL without credentials or fragment',
      );
    }
    result.add({'file': file, 'url': url});
  }
  return result;
}
