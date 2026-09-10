import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/errors/failure.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/service/shared/db/config_writer.dart';
import 'package:onexray/service/connect/raw/editor.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/advanced/xray/geodata/model.dart';
import 'package:onexray/service/advanced/xray/geodata/validator.dart';
import 'package:onexray/service/shared/ping/service.dart';
import 'package:onexray/service/shared/xray/validation.dart';
import 'package:onexray/service/shared/share/app_link_model.dart';
import 'package:onexray/service/shared/share/app_link_parser.dart';
import 'package:onexray/service/shared/share/service.dart';
import 'package:onexray/service/shared/share/configuration_transfer.dart';
import 'package:onexray/service/connect/routing/custom/service.dart';
import 'package:onexray/service/connect/routing/custom/document.dart';
import 'package:onexray/service/shared/in_flight_operations.dart';
import 'package:onexray/service/shared/share/xray_share_reader.dart';
import 'package:onexray/service/servers/subscription/model.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/servers/subscription/validator.dart';
import 'package:onexray/service/servers/outbound/map.dart';
import 'package:onexray/service/servers/outbound/state_db.dart';
import 'package:onexray/service/connect/raw/db.dart';
import 'package:onexray/service/connect/raw/validator.dart';
import 'package:path/path.dart' as p;

class ServerImportResult {
  final int count;
  final int? subscriptionId;
  final int rawCount;
  final int customCount;
  final int geoDataCount;
  final int subscriptionCount;
  final List<OneXrayGeoDataLink> failedGeoData;
  int get writeFailureCount => failedGeoData.length;
  const ServerImportResult({
    required this.count,
    this.subscriptionId,
    this.rawCount = 0,
    this.customCount = 0,
    this.geoDataCount = 0,
    this.subscriptionCount = 0,
    this.failedGeoData = const [],
  });
}

class ServerImportPreview {
  final List<CoreConfigCompanion> rows;
  final List<OneXrayGeoDataLink> geoData;
  final List<ConfigurationContent> customRoutes;
  final List<GeoDataInput> assets;
  final GeoDataImport? _dependencies;
  ServerImportPreview(
    Iterable<CoreConfigCompanion> rows, {
    Iterable<OneXrayGeoDataLink> geoData = const [],
    Iterable<ConfigurationContent> customRoutes = const [],
    this._dependencies,
    Iterable<GeoDataInput> assets = const [],
  }) : rows = List.unmodifiable(rows),
       geoData = List.unmodifiable(geoData),
       customRoutes = List.unmodifiable(customRoutes),
       assets = List.unmodifiable(assets);
  int get count => rows.where((row) => row.type.value == 'outbound').length;
  int get rawCount => rows.where((row) => row.type.value == 'raw').length;
  bool get hasItems =>
      rows.isNotEmpty || geoData.isNotEmpty || customRoutes.isNotEmpty;
  Future<void> dispose() async => _dependencies?.dispose();
}

class ServerImportDetection {
  final List<OneXraySubscriptionLink> subscriptions;
  final String localText;
  const ServerImportDetection(this.subscriptions, this.localText);
}

class ServerSubscriptionImport {
  final String name;
  final SubscriptionInsertResult result;
  const ServerSubscriptionImport(this.name, this.result);
}

/// Prepares content without writes; [commit] imports it after user-initiated input.
class ServerImportService {
  // Pages create import instances; clear-data pauses their shared import work.
  static final _imports = InFlightOperations();

  static Future<void> pauseForDataClear() => _imports.pause();

  static void resumeAfterDataClear() => _imports.resume();

  final AppDatabase? _database;
  final ConfigurationTransferService _transfer;
  final Future<bool> Function(String) _validateRaw;
  final Future<List<CoreConfigCompanion>> Function(String) _parse;
  final Future<String> Function(String) _validate;
  final Future<ConfigWriteResult> Function(List<CoreConfigCompanion>) _write;
  final void Function(List<int>) _schedule;
  final Future<SubscriptionInsertResult> Function(OneXraySubscriptionLink)
  _subscribe;
  final Future<bool> Function(OneXrayGeoDataLink) _validateGeoData;
  final Future<bool> Function(OneXrayGeoDataLink) _writeGeoData;

  ServerImportService({
    AppDatabase? database,
    ConfigurationTransferService? transfer,
    Future<List<CoreConfigCompanion>> Function(String)? parse,
    Future<String> Function(String)? validate,
    Future<ConfigWriteResult> Function(List<CoreConfigCompanion>)? write,
    void Function(List<int>)? schedule,
    Future<SubscriptionInsertResult> Function(OneXraySubscriptionLink)?
    subscribe,
    Future<bool> Function(OneXrayGeoDataLink)? validateGeoData,
    Future<bool> Function(OneXrayGeoDataLink)? writeGeoData,
  }) : _database = database,
       _transfer = transfer ?? ConfigurationTransferService(),
       _validateRaw = ((text) async {
         final result = await XrayRawValidator.validate(
           text,
           testXray: validate,
         );
         if (!result.isValid) {
           throw AppFailure(
             FailureCategory.configuration,
             'xrayValidation',
             cause: result.error,
           );
         }
         return true;
       }),
       _parse = parse ?? XrayShareReader().parseShareText,
       _validate = validate ?? AppHostApi().testXray,
       _write =
           write ??
           ((rows) => ConfigWriter.writeRowsInTransaction(
             database ?? AppDatabase(),
             rows,
             null,
           )),
       _schedule = schedule ?? PingService().schedulePingConfigIds,
       _subscribe = subscribe ?? _importSubscription,
       _validateGeoData =
           validateGeoData ??
           ((link) async =>
               (await GeoDataValidator.validate(link.name, link.url)).item1),
       _writeGeoData =
           writeGeoData ??
           ((link) async {
             await GeoDataService().add(
               GeoDataInput(
                 fileName: link.name,
                 type: link.type,
                 url: link.url,
               ),
             );
             return true;
           });

  static void _checkSize(String text) {
    if (text.trim().isEmpty || utf8.encode(text).length > 16 * 1024 * 1024) {
      throw const FormatException('Invalid import size');
    }
  }

  /// Classify before any writes. JSON/base64 stay intact for the native parser.
  ServerImportDetection detect(String text) {
    _checkSize(text);
    if (text.trimLeft().startsWith('{')) {
      return ServerImportDetection(const [], text);
    }
    final subscriptions = <OneXraySubscriptionLink>[];
    final local = <String>[];
    for (final line in text.split('\n')) {
      final link = singleLink(line);
      if (link is OneXraySubscriptionLink) {
        subscriptions.add(link);
      } else {
        local.add(line);
      }
    }
    return ServerImportDetection(
      List.unmodifiable(subscriptions),
      local.join('\n'),
    );
  }

  Future<List<ServerSubscriptionImport>> importSubscriptions(
    List<OneXraySubscriptionLink> links,
  ) => _imports.track(() async {
    final results = <ServerSubscriptionImport>[];
    for (final link in links) {
      if (_imports.isPaused) break;
      final name = link.name.trim().isEmpty
          ? Uri.parse(link.url).host
          : link.name.trim();
      try {
        results.add(ServerSubscriptionImport(name, await _subscribe(link)));
      } catch (error) {
        results.add(
          ServerSubscriptionImport(
            name,
            SubscriptionInsertResult(
              status: SubscriptionUpdateResult.writeFailed,
              error: error,
            ),
          ),
        );
      }
    }
    return List.unmodifiable(results);
  });

  static Future<SubscriptionInsertResult> _importSubscription(
    OneXraySubscriptionLink link,
  ) async {
    if (!NetClient.isHttpsDownloadUri(Uri.parse(link.url))) {
      return const SubscriptionInsertResult(
        status: SubscriptionUpdateResult.invalidContent,
      );
    }
    final service = SubscriptionService();
    for (final row in await AppDatabase().subscriptionDao.allRows) {
      if (row.url != link.url) continue;
      final result = await service.refreshSubscriptionResult(row);
      return SubscriptionInsertResult(
        status: result.status,
        subId: row.id,
        count: result.count,
        error: result.error,
      );
    }
    String? secretKey;
    String? publicKey;
    if (link.ageKeyType != null) {
      final pair = await AppHostApi().generateAgeKeyPair(
        keyType: link.ageKeyType!,
      );
      secretKey = pair.secretKey;
      publicKey = pair.publicKey;
      if (secretKey?.isNotEmpty != true || publicKey?.isNotEmpty != true) {
        return const SubscriptionInsertResult(
          status: SubscriptionUpdateResult.invalidAgeSecretKey,
        );
      }
    }
    final name = link.name.trim().isEmpty
        ? Uri.parse(link.url).host
        : link.name.trim();
    if (!(await SubscriptionValidator.validate(name, link.url)).item1) {
      return const SubscriptionInsertResult(
        status: SubscriptionUpdateResult.invalidContent,
      );
    }
    return service.insertSubscription(
      SubscriptionInput(
        name: name,
        url: link.url,
        ageSecretKey: secretKey,
        agePublicKey: publicKey,
      ),
    );
  }

  Future<ServerImportPreview> preview(
    String text, {
    bool manual = false,
  }) async {
    _checkSize(text);
    if (!manual) {
      if (text.trimLeft().startsWith('{')) {
        final json = jsonDecode(text);
        if (json is Map<String, dynamic>) {
          final outbounds = json['outbounds'];
          final custom =
              outbounds is List &&
              outbounds.any(
                (item) =>
                    item == null ||
                    (item is Map && (item.isEmpty || item['tag'] == '')),
              );
          final raw = json.keys.any(
            const {'inbounds', 'routing', 'dns', 'fakedns'}.contains,
          );
          if (custom || raw) {
            final content = ConfigurationTransferService.read(
              text,
              custom ? ConfigurationKind.custom : ConfigurationKind.raw,
            );
            return _configurationPreview([], [content], []);
          }
        }
        return ServerImportPreview(await _parse(text));
      }
      final rows = <CoreConfigCompanion>[];
      final geoData = <OneXrayGeoDataLink>[];
      final other = <String>[];
      final configurations = <ConfigurationContent>[];
      final parsedLinks = [
        for (final line in text.split('\n'))
          if (Uri.tryParse(line.trim()) case final uri?)
            OneXrayAppLinkParser.parse(uri),
      ];
      final usedGeoData = <OneXrayGeoDataLink>{};
      for (final line in text.split('\n')) {
        final uri = Uri.tryParse(line.trim());
        final link = uri == null ? null : OneXrayAppLinkParser.parse(uri);
        if (link == null) {
          if (uri?.scheme.toLowerCase() == OneXrayAppLinkParser.scheme) {
            continue;
          }
          other.add(line);
          continue;
        }
        try {
          if (link is OneXrayConfigLink &&
              link.type == OneXrayConfigLinkType.outbound) {
            final outbound = decodeSingleOutbound(
              link.xrayJson,
              nameAlias: link.name.isEmpty ? null : link.name,
            );
            final error = await _validate(XrayValidation.nodes([outbound]));
            if (error.isNotEmpty) {
              throw AppFailure(
                FailureCategory.configuration,
                'xrayValidation',
                cause: error,
              );
            }
            rows.add(outboundCompanion(outbound));
          } else if (link is OneXrayConfigLink &&
              (link.type == OneXrayConfigLinkType.raw ||
                  link.type == OneXrayConfigLinkType.custom)) {
            final kind = link.type == OneXrayConfigLinkType.raw
                ? ConfigurationKind.raw
                : ConfigurationKind.custom;
            final dependencies = <String>[];
            if (kind == ConfigurationKind.raw) {
              final references = geoDataReferences(
                jsonDecode(link.xrayJson) as Map<String, dynamic>,
              );
              for (final data in parsedLinks.whereType<OneXrayGeoDataLink>()) {
                if (references.containsKey(data.name) ||
                    references.containsKey('${data.name}.dat')) {
                  usedGeoData.add(data);
                  dependencies.add(
                    Uri(
                      scheme: OneXrayAppLinkParser.scheme,
                      host: OneXrayAppLinkParser.host,
                      path: OneXrayAppLinkParser.geoDataPath,
                      queryParameters: {
                        'type': data.type.name,
                        'url': data.url,
                      },
                      fragment: data.name,
                    ).toString(),
                  );
                }
              }
            }
            configurations.add(
              ConfigurationTransferService.read(
                [line, ...dependencies].join('\n'),
                kind,
              ),
            );
          } else if (link is OneXrayGeoDataLink) {
            geoData.add(link);
          } else {
            throw const FormatException('Unsupported local asset');
          }
        } catch (_) {
          // Skip invalid links without discarding the remaining input.
        }
      }
      if (other.any((line) => line.trim().isNotEmpty)) {
        try {
          rows.addAll(await _parse(other.join('\n')));
        } catch (_) {
          // Other valid App links in this input may still be imported.
        }
      }
      geoData.removeWhere(
        (link) => usedGeoData.any(
          (used) =>
              used.name == link.name &&
              used.type == link.type &&
              used.url == link.url,
        ),
      );
      final standalone = <OneXrayGeoDataLink>[];
      for (final link in geoData) {
        if (!_safeGeoDataName(link.name) ||
            !NetClient.isHttpsDownloadUri(Uri.parse(link.url)) ||
            !await _validateGeoData(link) ||
            standalone.any((item) => item.name == link.name)) {
          continue;
        }
        standalone.add(link);
      }
      return _configurationPreview(rows, configurations, standalone);
    }
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> ||
        json['outbounds'] is! List ||
        (json['outbounds'] as List).isEmpty) {
      throw const FormatException('A non-empty outbounds array is required');
    }
    final error = await _validate(
      XrayValidation.nodes(json['outbounds'] as List),
    );
    if (error.isNotEmpty) {
      throw AppFailure(
        FailureCategory.configuration,
        'xrayValidation',
        cause: error,
      );
    }
    return ServerImportPreview([
      for (final outbound in json['outbounds'] as List)
        outboundCompanion(outbound as Map<String, dynamic>),
    ]);
  }

  Future<ServerImportPreview> _configurationPreview(
    List<CoreConfigCompanion> rows,
    List<ConfigurationContent> contents,
    List<OneXrayGeoDataLink> standalone,
  ) async {
    final custom = contents
        .where((item) => item.kind == ConfigurationKind.custom)
        .toList();
    if (custom.length > 3 || contents.any((item) => item.name.trim().isEmpty)) {
      throw const FormatException('Invalid configuration name or count');
    }
    final assets = [for (final content in contents) ...content.assets];
    final draft = await _transfer.prepareAssets(assets);
    try {
      if (draft == null) {
        for (final route in custom) {
          await CustomRoutingService.validate(
            RoutingProfileDocument.parse(
              route.text,
              allowMetadata: false,
            ).state,
            testXray: _validate,
          );
        }
      }
      for (final raw in contents.where(
        (item) => item.kind == ConfigurationKind.raw,
      )) {
        final text = RawEditorService.namedText(raw.name, raw.text);
        if (draft == null && !await _validateRaw(text)) {
          throw const FormatException('Invalid Raw');
        }
        rows.add(XrayRawDb.configCompanion(raw.name.trim(), text));
      }
      return ServerImportPreview(
        rows,
        customRoutes: custom,
        dependencies: draft,
        assets: assets,
        geoData: standalone,
      );
    } catch (_) {
      await draft?.dispose();
      rethrow;
    }
  }

  Future<ServerImportResult> commit(ServerImportPreview preview) =>
      _imports.track(() async {
        if (!preview.hasItems) {
          throw const FormatException('No usable servers');
        }
        return _commitPreview(preview);
      });

  Future<ServerImportResult> _commitPreview(ServerImportPreview preview) async {
    late final db = _database ?? AppDatabase();
    Future<ConfigWriteResult?> save(
      Future<void> Function() writeMetadata,
    ) async {
      if (preview._dependencies != null) {
        for (final route in preview.customRoutes) {
          await CustomRoutingService.validate(
            RoutingProfileDocument.parse(
              route.text,
              allowMetadata: false,
            ).state,
            testXray: _validate,
          );
        }
        for (final row in preview.rows.where(
          (row) => row.type.value == 'raw',
        )) {
          final data = row.data.value;
          if (data == null ||
              !await _validateRaw(utf8.decode(base64Decode(data)))) {
            throw const FormatException('Invalid Raw');
          }
        }
      }
      Future<ConfigWriteResult?> write() async {
        await writeMetadata();
        final result = preview.rows.isEmpty ? null : await _write(preview.rows);
        if (result != null &&
            (result.count != preview.rows.length ||
                result.ids.length != preview.rows.length)) {
          throw StateError('Incomplete asset write');
        }
        for (final custom in preview.customRoutes) {
          await CustomRoutingService(db).save(
            RoutingProfileDocument.parse(
              custom.text,
              name: custom.name,
              allowMetadata: false,
            ).state,
          );
        }
        return result;
      }

      return preview._dependencies != null || preview.customRoutes.isNotEmpty
          ? db.transaction(write)
          : write();
    }

    final result = preview._dependencies != null
        ? await preview._dependencies.save(save)
        : preview.customRoutes.isNotEmpty
        ? await GeoDataService().withFiles(() => save(() async {}))
        : await save(() async {});
    if (result != null && !_imports.isPaused) {
      _schedule([
        for (var index = 0; index < result.ids.length; index++)
          if (preview.rows[index].type.value == 'outbound') result.ids[index],
      ]);
    }
    var geoDataCount = 0;
    final failures = <OneXrayGeoDataLink>[];
    for (final link in preview.geoData) {
      if (_imports.isPaused) {
        failures.add(link);
        continue;
      }
      try {
        if (await _writeGeoData(link)) {
          geoDataCount++;
        } else {
          failures.add(link);
        }
      } catch (_) {
        failures.add(link);
      }
    }
    return ServerImportResult(
      count: preview.count,
      rawCount: preview.rawCount,
      customCount: preview.customRoutes.length,
      geoDataCount: geoDataCount,
      failedGeoData: List.unmodifiable(failures),
    );
  }

  static bool _safeGeoDataName(String name) =>
      name.isNotEmpty &&
      !name.endsWith('.') &&
      !name.endsWith(' ') &&
      !RegExp(r'[/\\:*?"<>|\x00-\x1f]').hasMatch(name) &&
      !RegExp(
        r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)',
        caseSensitive: false,
      ).hasMatch(name);

  /// Recognizes one link without importing it.
  static OneXrayAppLink? singleLink(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || text.trim().contains('\n')) return null;
    final link = OneXrayAppLinkParser.parse(uri);
    if (link != null) return link;
    if (!NetClient.isHttpsDownloadUri(uri)) return null;
    return OneXraySubscriptionLink(
      name: uri.fragment,
      url: SubscriptionUrl.normalize(uri.toString()),
    );
  }

  static Future<String?> pickTextFile({bool jsonOnly = false}) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: jsonOnly
          ? ['json', 'txt']
          : ['json', 'txt', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (file == null) {
      return null;
    }
    if (file.path == null) {
      throw const FormatException('Cannot read selected file');
    }
    final input = File(file.path!);
    if (await input.length() > 16 * 1024 * 1024) {
      throw const FormatException('Invalid import size');
    }
    if ([
      '.png',
      '.jpg',
      '.jpeg',
      '.webp',
    ].contains(p.extension(file.path!).toLowerCase())) {
      final text = await ShareService().readImageFile(file.path!);
      if (text == null || text.trim().isEmpty) {
        throw const FormatException('No QR code recognized');
      }
      _checkSize(text);
      return text;
    }
    return input.readAsString();
  }

  static Future<String?> pickQrImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    if (await File(image.path).length() > 16 * 1024 * 1024) {
      throw const FormatException('Invalid import size');
    }
    final text = await ShareService().readImageFile(image.path);
    if (text == null) throw const FormatException('No QR code recognized');
    _checkSize(text);
    return text;
  }

  static Future<String?> readClipboard() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;
}
