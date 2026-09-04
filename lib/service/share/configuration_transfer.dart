import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/routing/document.dart';
import 'package:onexray/service/share/app_link_generator.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/app_link_parser.dart';

enum ConfigurationKind { raw, custom }

class ConfigurationContent {
  final ConfigurationKind kind;
  final String text;
  final String name;
  final List<GeoDataInput> assets;
  const ConfigurationContent({
    required this.kind,
    required this.text,
    required this.name,
    this.assets = const [],
  });
}

class ConfigurationImportDraft {
  final ConfigurationContent content;
  final GeoDataImportDraft? geodata;
  const ConfigurationImportDraft(this.content, this.geodata);
  String get text => content.text;
  String get name => content.name;
  Future<void> commit() async => geodata?.commit();
  Future<void> dispose() async => geodata?.dispose();
}

/// Editor transfers preserve Raw source and never save a configuration. Custom
/// manifests are consumed into a staged Geodata transaction, not persisted JSON.
class ConfigurationTransferService {
  final Future<GeoDataImportDraft> Function(List<GeoDataInput>) _prepare;
  final Future<GeoDataData?> Function(String) _lookup;
  ConfigurationTransferService({
    Future<GeoDataImportDraft> Function(List<GeoDataInput>)? prepare,
    Future<GeoDataData?> Function(String)? lookup,
  }) : _prepare = prepare ?? GeoDataService().prepareImports,
       _lookup =
           lookup ?? ((name) => AppDatabase().geoDataDao.searchRowByName(name));

  Future<ConfigurationImportDraft> import(
    String input,
    ConfigurationKind kind,
  ) async {
    final content = read(input, kind);
    return ConfigurationImportDraft(
      content,
      content.assets.isEmpty ? null : await _prepare(content.assets),
    );
  }

  Future<GeoDataImportDraft?> prepareAssets(List<GeoDataInput> inputs) async =>
      inputs.isEmpty ? null : _prepare(inputs);

  static ConfigurationContent read(String input, ConfigurationKind kind) {
    if (input.trim().isEmpty || utf8.encode(input).length > 16 * 1024 * 1024) {
      throw const FormatException('Invalid configuration size');
    }
    var text = input;
    var name = '';
    final linked = <OneXrayGeoDataLink>[];
    if (!input.trimLeft().startsWith('{')) {
      OneXrayConfigLink? configuration;
      for (final line
          in input.split('\n').where((line) => line.trim().isNotEmpty)) {
        final uri = Uri.tryParse(line.trim());
        final link = uri == null ? null : OneXrayAppLinkParser.parse(uri);
        if (link is OneXrayConfigLink && configuration == null) {
          final expected = kind == ConfigurationKind.raw
              ? OneXrayConfigLinkType.raw
              : OneXrayConfigLinkType.custom;
          if (link.type != expected) {
            throw const FormatException('Unexpected configuration type');
          }
          configuration = link;
        } else if (link is OneXrayGeoDataLink &&
            kind == ConfigurationKind.raw) {
          linked.add(link);
        } else {
          throw const FormatException('Expected one configuration');
        }
      }
      if (configuration == null) {
        throw const FormatException('Missing configuration');
      }
      text = configuration.xrayJson;
      name = configuration.name;
    }
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Configuration must be an object');
    }
    if (name.isEmpty && json['name'] is String) name = json['name'] as String;
    final references = geoDataReferences(json);
    final assets = <GeoDataInput>[];
    if (kind == ConfigurationKind.custom) {
      final document = RoutingProfileDocument.parse(
        text,
        name: name.isEmpty ? null : name,
      );
      text = document.state.encode();
      if (name.isEmpty) name = document.state.name;
      for (final asset in document.assets) {
        final file = asset['file']!;
        final type = references[file];
        if (type == null) {
          throw const FormatException(
            'Geodata manifest contains an unused file',
          );
        }
        assets.add(_asset(file, type, asset['url']!));
      }
    } else {
      for (final link in linked) {
        // Existing links carry a database basename; newer links may carry the
        // full filename. Neither case is allowed to rename an ext reference.
        final file = references.containsKey(link.name)
            ? link.name
            : '${link.name}.dat';
        if (references[file] != link.type) {
          throw const FormatException(
            'Geodata link does not match its reference',
          );
        }
        assets.add(_asset(file, link.type, link.url));
      }
    }
    final names = <String>{};
    for (final asset in assets) {
      if (!names.add(asset.fileName.toLowerCase())) {
        throw const FormatException('Duplicate Geodata filename');
      }
    }
    return ConfigurationContent(
      kind: kind,
      text: text,
      name: name,
      assets: List.unmodifiable(assets),
    );
  }

  static GeoDataInput _asset(String file, GeoDataType type, String url) {
    if (GeoDataInput.canonicalFileName(file) != file) {
      throw const FormatException('Geodata filename must match the reference');
    }
    GeoDataInput.httpsUri(url);
    return GeoDataInput(fileName: file, type: type, url: url);
  }

  Future<String> exportJson({
    required ConfigurationKind kind,
    required String name,
    required String text,
    GeoDataImportDraft? pending,
  }) async {
    if (kind == ConfigurationKind.raw) return text;
    final state = RoutingProfileDocument.parse(text, name: name).state;
    final assets = await _dependencies(state.xrayJson.toJson(), pending);
    final xrayJson = state.xrayJson;
    if (assets.isNotEmpty) {
      xrayJson.geodata = XrayGeoData(
        assets: [
          for (final asset in assets)
            XrayGeoDataAsset(file: asset.fileName, url: asset.url),
        ],
      );
    }
    return const JsonEncoder.withIndent('  ')
        .convert({...xrayJson.toJson(), 'name': name.trim()});
  }

  Future<String> shareLinks({
    required ConfigurationKind kind,
    required String name,
    required String text,
    GeoDataImportDraft? pending,
  }) async {
    final json = await exportJson(
      kind: kind,
      name: name,
      text: text,
      pending: pending,
    );
    final links = <String>[];
    if (kind == ConfigurationKind.raw) {
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      for (final asset in await _dependencies(decoded, pending)) {
        links.add(
          Uri(
            scheme: OneXrayAppLinkParser.scheme,
            host: OneXrayAppLinkParser.host,
            path: OneXrayAppLinkParser.geoDataPath,
            queryParameters: {'type': asset.type.name, 'url': asset.url},
            fragment: asset.name,
          ).toString(),
        );
      }
    }
    links.add(
      OneXrayAppLinkGenerator.configurationText(
        kind == ConfigurationKind.raw
            ? OneXrayConfigLinkType.raw
            : OneXrayConfigLinkType.custom,
        name,
        json,
      ).toString(),
    );
    return links.join('\n');
  }

  Future<int> sharingDataCount(
    String text, {
    GeoDataImportDraft? pending,
  }) async => (await _dependencies(
    jsonDecode(text) as Map<String, dynamic>,
    pending,
  )).length;

  Future<List<GeoDataInput>> _dependencies(
    Map<String, dynamic> json,
    GeoDataImportDraft? pending,
  ) async {
    final result = <GeoDataInput>[];
    for (final entry in geoDataReferences(json).entries) {
      GeoDataInput? input;
      for (final asset in pending?.inputs ?? const <GeoDataInput>[]) {
        if (asset.fileName == entry.key && asset.type == entry.value) {
          input = asset;
        }
      }
      if (input == null) {
        final row = await _lookup(entry.key.substring(0, entry.key.length - 4));
        if (row == null || row.type != entry.value.name) {
          throw const FormatException('Referenced Geodata is unavailable');
        }
        input = _asset(entry.key, entry.value, row.url);
      }
      result.add(input);
    }
    return result;
  }
}

/// Parse only Xray fields that accept domain/IP Geodata references, not arbitrary
/// strings (credentials, remarks and URLs can also contain the text "ext:").
Map<String, GeoDataType> geoDataReferences(Map<String, dynamic> json) {
  final result = <String, GeoDataType>{};
  void add(Object? values, GeoDataType type) {
    if (values is! List) return;
    for (final value in values.whereType<String>()) {
      final match = RegExp(r'^ext:([^:]+\.dat):.+$').firstMatch(value);
      if (match == null) continue;
      final file = match.group(1)!;
      if (file == 'geosite.dat' || file == 'geoip.dat') continue;
      if (result.containsKey(file) && result[file] != type) {
        throw const FormatException('A Geodata file cannot have two types');
      }
      if (GeoDataInput.canonicalFileName(file) != file) {
        throw const FormatException(
          'Geodata filename must match its reference',
        );
      }
      result[file] = type;
    }
  }

  final routing = json['routing'];
  if (routing is Map && routing['rules'] is List) {
    for (final rule in (routing['rules'] as List).whereType<Map>()) {
      add(rule['domain'], GeoDataType.domain);
      add(rule['ip'], GeoDataType.ip);
      add(rule['source'], GeoDataType.ip);
    }
  }
  final dns = json['dns'];
  if (dns is Map && dns['servers'] is List) {
    for (final server in (dns['servers'] as List).whereType<Map>()) {
      add(server['domains'], GeoDataType.domain);
      add(server['expectedIPs'], GeoDataType.ip);
      add(server['unexpectedIPs'], GeoDataType.ip);
    }
  }
  return result;
}
