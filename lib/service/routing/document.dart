import 'dart:convert';

import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/routing/state.dart';
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
    _validateDocument(document);
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

void _validateDocument(Map<String, dynamic> document) {
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

void _validateRule(Map<String, dynamic> rule, int index) {
  final path = 'routing.rules[$index]';
  _onlyKeys(rule, const {
    'ruleTag',
    'domain',
    'ip',
    'port',
    'network',
    'balancerTag',
    'outboundTag',
  }, path);
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
    RoutingRuleState(
      port: rule['port'],
      action: RoutingRuleAction.proxy,
    ).validate();
    hasCondition = true;
  }
  if (rule.containsKey('network')) {
    RoutingRuleState(
      network: rule['network'],
      action: RoutingRuleAction.proxy,
    ).validate();
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
