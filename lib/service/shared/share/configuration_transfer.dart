import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/service/advanced/xray/geodata/model.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/connect/routing/custom/document.dart';
import 'package:onexray/service/connect/routing/custom/advanced.dart';
import 'package:onexray/service/connect/routing/custom/configuration.dart';
import 'package:onexray/service/shared/share/app_link_generator.dart';
import 'package:onexray/service/shared/share/app_link_model.dart';
import 'package:onexray/service/shared/share/app_link_parser.dart';

enum ConfigurationKind {
  raw(OneXrayConfigLinkType.raw),
  custom(OneXrayConfigLinkType.custom),
  customAdvanced(OneXrayConfigLinkType.customAdvanced);

  const ConfigurationKind(this.linkType);
  final OneXrayConfigLinkType linkType;
}

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
  final GeoDataImport? _geodata;
  const ConfigurationImportDraft(this.content, this._geodata);
  String get text => content.text;
  String get name => content.name;
  Future<T> save<T>(
    Future<T> Function(Future<void> Function() writeMetadata) action,
  ) => _geodata?.save(action) ?? action(() async {});
  Future<void> dispose() async => _geodata?.dispose();
}

/// Editor transfers preserve Raw source and never save a configuration. Custom
/// manifests are consumed into a staged Geodata transaction, not persisted JSON.
class ConfigurationTransferService {
  static ({RoutingConfiguration state, List<Map<String, String>> assets})
  routingDocument(
    String text,
    ConfigurationKind kind, {
    String? name,
    bool allowMetadata = true,
  }) {
    if (kind == ConfigurationKind.customAdvanced) {
      final doc = AdvancedRoutingDocument.parse(
        text,
        name: name,
        allowMetadata: allowMetadata,
      );
      return (state: doc.state, assets: doc.assets);
    }
    if (kind != ConfigurationKind.custom) {
      throw const FormatException('Expected Custom routing');
    }
    final doc = RoutingProfileDocument.parse(
      text,
      name: name,
      allowMetadata: allowMetadata,
    );
    return (state: doc.state, assets: doc.assets);
  }

  final Future<GeoDataImport> Function(List<GeoDataInput>) _prepare;
  final Future<GeoDataData?> Function(String) _lookup;
  ConfigurationTransferService({
    Future<GeoDataImport> Function(List<GeoDataInput>)? prepare,
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

  Future<GeoDataImport?> prepareAssets(List<GeoDataInput> inputs) async =>
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
          final expected = kind.linkType;
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
    if (kind != ConfigurationKind.raw) {
      final document = routingDocument(
        text,
        kind,
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
    GeoDataInput.referenceFileName(file);
    GeoDataInput.httpsUri(url);
    return GeoDataInput(fileName: file, type: type, url: url);
  }

  Future<String> exportJson({
    required ConfigurationKind kind,
    required String name,
    required String text,
    List<GeoDataInput> assets = const [],
  }) async {
    if (kind == ConfigurationKind.raw) return text;
    final state = routingDocument(text, kind, name: name).state;
    final dependencies = await _dependencies(state.toJson(), assets);
    final json = state.toJson();
    if (dependencies.isNotEmpty) {
      json['geodata'] = {
        'assets': [
          for (final asset in dependencies)
            {'file': asset.fileName, 'url': asset.url},
        ],
      };
    }
    return const JsonEncoder.withIndent('  ')
        .convert({...json, 'name': name.trim()});
  }

  Future<String> shareLinks({
    required ConfigurationKind kind,
    required String name,
    required String text,
    List<GeoDataInput> assets = const [],
  }) async {
    final json = await exportJson(
      kind: kind,
      name: name,
      text: text,
      assets: assets,
    );
    final links = <String>[];
    if (kind == ConfigurationKind.raw) {
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      for (final asset in await _dependencies(decoded, assets)) {
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
        kind.linkType,
        name,
        json,
      ).toString(),
    );
    return links.join('\n');
  }

  Future<int> sharingDataCount(
    String text, {
    List<GeoDataInput> assets = const [],
  }) async => (await _dependencies(
    jsonDecode(text) as Map<String, dynamic>,
    assets,
  )).length;

  Future<List<GeoDataInput>> _dependencies(
    Map<String, dynamic> json,
    List<GeoDataInput> assets,
  ) async {
    final result = <GeoDataInput>[];
    for (final entry in geoDataReferences(json).entries) {
      GeoDataInput? input;
      for (final asset in assets) {
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
    if (values is String) values = [values];
    if (values is! List) return;
    for (final value in values.whereType<String>()) {
      final reference = type == GeoDataType.ip && value.startsWith('!')
          ? value.substring(1)
          : value;
      final match = RegExp(r'^ext:([^:]+\.dat):.+$').firstMatch(reference);
      if (match == null) continue;
      final file = match.group(1)!;
      if (file == 'geosite.dat' || file == 'geoip.dat') continue;
      if (result.containsKey(file) && result[file] != type) {
        throw const FormatException('A Geodata file cannot have two types');
      }
      GeoDataInput.referenceFileName(file);
      result[file] = type;
    }
  }

  final routing = json['routing'];
  if (routing is Map && routing['rules'] is List) {
    for (final rule in (routing['rules'] as List).whereType<Map>()) {
      add(rule['domain'], GeoDataType.domain);
      add(rule['ip'], GeoDataType.ip);
      add(rule['sourceIP'] ?? rule['source'], GeoDataType.ip);
      add(rule['localIP'], GeoDataType.ip);
    }
  }
  final dns = json['dns'];
  if (dns is Map && dns['hosts'] is Map) {
    add((dns['hosts'] as Map).keys.toList(), GeoDataType.domain);
  }
  if (dns is Map && dns['servers'] is List) {
    for (final server in (dns['servers'] as List).whereType<Map>()) {
      add(server['domains'], GeoDataType.domain);
      add(server['expectedIPs'], GeoDataType.ip);
      add(server['expectIPs'], GeoDataType.ip);
      add(server['unexpectedIPs'], GeoDataType.ip);
    }
  }
  final inbounds = json['inbounds'];
  if (inbounds is List) {
    for (final inbound in inbounds.whereType<Map>()) {
      final sniffing = inbound['sniffing'];
      if (sniffing is Map) {
        add(sniffing['domainsExcluded'], GeoDataType.domain);
        add(sniffing['ipsExcluded'], GeoDataType.ip);
      }
    }
  }
  final outbounds = json['outbounds'];
  if (outbounds is List) {
    for (final outbound in outbounds.whereType<Map>()) {
      if (outbound['protocol'] != 'dns') continue;
      final settings = outbound['settings'];
      final rules = settings is Map ? settings['rules'] : null;
      if (rules is List) {
        for (final rule in rules.whereType<Map>()) {
          add(rule['domain'], GeoDataType.domain);
        }
      }
    }
  }
  return result;
}
