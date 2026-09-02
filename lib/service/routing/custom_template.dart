import 'dart:convert';

import 'package:onexray/core/tools/json.dart';
import 'package:path/path.dart' as p;

/// The editable Xray template, not a runnable config or a persisted UI model.
/// Importers must prepare [assets] before saving [toJson] or [encode].
/// Xray still validates domain/IP expressions and installed Geodata references
/// when checking the compiled draft; this parser never queries DNS or files.
final class CustomRoutingTemplate {
  final Map<String, dynamic> _document;
  final List<Map<String, String>> _assets;
  final int entryCount;

  CustomRoutingTemplate._(this._document, this._assets, this.entryCount);

  factory CustomRoutingTemplate.parse(String text) {
    final document = _object(jsonDecode(text), 'template');
    _onlyKeys(document, const {
      'name',
      'outbounds',
      'routing',
      'geodata',
    }, 'template');
    if (document.containsKey('name')) {
      final name = document['name'];
      if (name is! String ||
          name.trim().isEmpty ||
          name.trim().runes.length > 32) {
        throw const FormatException('name must contain 1–32 characters');
      }
    }

    final outbounds = document['outbounds'];
    if (outbounds is! List) {
      throw const FormatException('outbounds must be an array');
    }
    var entryCount = 0;
    final tags = <String>{};
    for (var index = 0; index < outbounds.length; index++) {
      final path = 'outbounds[$index]';
      final outbound = _object(outbounds[index], path);
      if (outbound.isEmpty) {
        entryCount++;
        continue;
      }
      _onlyKeys(outbound, const {'tag', 'protocol', 'settings'}, path);
      final tag = outbound['tag'];
      final expected = switch (tag) {
        'direct' => 'freedom',
        'block' => 'blackhole',
        _ => null,
      };
      if (expected == null || outbound['protocol'] != expected) {
        throw FormatException('$path must be a direct or block outbound');
      }
      if (!tags.add(tag as String)) {
        throw FormatException('$path duplicates a functional outbound');
      }
      if (outbound.containsKey('settings') &&
          _object(outbound['settings'], '$path.settings').isNotEmpty) {
        throw FormatException(
          '$path.settings cannot be edited by Custom routing',
        );
      }
    }
    if (entryCount < 1 || entryCount > 3) {
      throw const FormatException(
        'outbounds must contain 1–3 empty object slots',
      );
    }

    final routing = document.containsKey('routing')
        ? _object(document['routing'], 'routing')
        : <String, dynamic>{};
    _onlyKeys(routing, const {'domainStrategy', 'rules'}, 'routing');
    if (routing.containsKey('domainStrategy') &&
        !const {'AsIs', 'IPIfNonMatch'}.contains(routing['domainStrategy'])) {
      throw const FormatException('Unsupported routing.domainStrategy');
    }
    final rules = routing.containsKey('rules') ? routing['rules'] : <dynamic>[];
    if (rules is! List) {
      throw const FormatException('routing.rules must be an array');
    }
    for (var index = 0; index < rules.length; index++) {
      _validateRule(_object(rules[index], 'routing.rules[$index]'), index);
    }

    final assets = document.containsKey('geodata')
        ? _readAssets(document['geodata'])
        : <Map<String, String>>[];
    document.remove('geodata');
    return CustomRoutingTemplate._(document, assets, entryCount);
  }

  String? get name => _document['name'] as String?;

  String get domainStrategy =>
      (_document['routing'] as Map<String, dynamic>?)?['domainStrategy']
          as String? ??
      'AsIs';

  List<Map<String, dynamic>> get rules =>
      (((_document['routing'] as Map<String, dynamic>?)?['rules'] as List?) ??
              const [])
          .map((rule) => _copy(rule as Map<String, dynamic>))
          .toList();

  List<Map<String, String>> get assets =>
      _assets.map((asset) => Map<String, String>.from(asset)).toList();

  /// Storage/runtime form. The import-only manifest remains available in [assets].
  Map<String, dynamic> toJson() => _copy(_document);

  String encode() => JsonTool.encoder.convert(_document);
}

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

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

void _validateRule(Map<String, dynamic> rule, int index) {
  final path = 'routing.rules[$index]';
  _onlyKeys(rule, const {
    'type',
    'ruleTag',
    'domain',
    'ip',
    'port',
    'network',
    'balancerTag',
    'outboundTag',
  }, path);
  if (rule.containsKey('type') && rule['type'] != 'field') {
    throw FormatException('$path.type must be field');
  }
  if (rule.containsKey('ruleTag') &&
      (rule['ruleTag'] is! String ||
          (rule['ruleTag'] as String).trim().isEmpty)) {
    throw FormatException('$path.ruleTag must be a non-empty string');
  }
  final balancer = rule.containsKey('balancerTag');
  final outbound = rule.containsKey('outboundTag');
  if (balancer == outbound ||
      (balancer && rule['balancerTag'] != 'proxy') ||
      (outbound && !const {'direct', 'block'}.contains(rule['outboundTag']))) {
    throw FormatException(
      '$path must select exactly one VPN, direct or block action',
    );
  }

  var hasCondition = false;
  for (final key in const ['domain', 'ip']) {
    if (!rule.containsKey(key)) continue;
    final values = rule[key];
    if (values is! List ||
        values.any((value) => value is! String || value.trim().isEmpty)) {
      throw FormatException('$path.$key must be an array of non-empty strings');
    }
    hasCondition = hasCondition || values.isNotEmpty;
  }
  if (rule.containsKey('port')) {
    final port = rule['port'];
    if (port is! int && port is! String) {
      throw FormatException(
        '$path.port must be a port or comma-separated ranges',
      );
    }
    for (final part in '$port'.split(',')) {
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
        throw FormatException('$path.port contains an invalid port range');
      }
    }
    hasCondition = true;
  }
  if (rule.containsKey('network')) {
    final network = rule['network'];
    final values = network is String ? network.split(',') : network;
    if (values is! List ||
        values.isEmpty ||
        values.any((value) => value != 'tcp' && value != 'udp')) {
      throw FormatException('$path.network must contain only tcp or udp');
    }
    hasCondition = true;
  }
  if (!hasCondition) {
    throw FormatException('$path requires at least one non-empty condition');
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
