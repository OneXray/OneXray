import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/assets/raw_editor.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/validator.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/app_link_parser.dart';
import 'package:onexray/service/share/service.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/raw/db.dart';
import 'package:onexray/service/xray/raw/validator.dart';
import 'package:path/path.dart' as p;

class ServerImportResult {
  final int count;
  final int? subscriptionId;
  final int? failureCount;
  final int rawCount;
  final int geoDataCount;
  final int subscriptionCount;
  final List<OneXrayGeoDataLink> failedGeoData;
  int get writeFailureCount => failedGeoData.length;
  const ServerImportResult({
    required this.count,
    this.subscriptionId,
    this.failureCount,
    this.rawCount = 0,
    this.geoDataCount = 0,
    this.subscriptionCount = 0,
    this.failedGeoData = const [],
  });
}

class ServerImportPreview {
  final List<CoreConfigCompanion> rows;
  final List<OneXrayGeoDataLink> geoData;
  final int? failureCount;
  ServerImportPreview(
    Iterable<CoreConfigCompanion> rows, {
    this.failureCount,
    Iterable<OneXrayGeoDataLink> geoData = const [],
  }) : rows = List.unmodifiable(rows),
       geoData = List.unmodifiable(geoData);
  int get count => rows.where((row) => row.type.value == 'outbound').length;
  int get rawCount => rows.where((row) => row.type.value == 'raw').length;
  bool get hasItems => rows.isNotEmpty || geoData.isNotEmpty;
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

/// Local detection is read-only. Only an explicit confirmation calls [commit].
class ServerImportService {
  final Future<ShareParseReport> Function(String) _parse;
  final Future<String> Function(String) _validate;
  final Future<ConfigWriteResult> Function(List<CoreConfigCompanion>) _write;
  final void Function(List<int>) _schedule;
  final Future<SubscriptionInsertResult> Function(OneXraySubscriptionLink)
  _subscribe;
  final Future<bool> Function(OneXrayGeoDataLink) _validateGeoData;
  final Future<bool> Function(OneXrayGeoDataLink) _writeGeoData;

  ServerImportService({
    Future<List<CoreConfigCompanion>> Function(String)? parse,
    Future<ShareParseReport> Function(String)? parseReport,
    Future<String> Function(String)? validate,
    Future<ConfigWriteResult> Function(List<CoreConfigCompanion>)? write,
    void Function(List<int>)? schedule,
    Future<SubscriptionInsertResult> Function(OneXraySubscriptionLink)?
    subscribe,
    Future<bool> Function(OneXrayGeoDataLink)? validateGeoData,
    Future<bool> Function(OneXrayGeoDataLink)? writeGeoData,
  }) : _parse =
           parseReport ??
           (parse == null
               ? XrayShareReader().parseShareTextReport
               : (text) async => ShareParseReport(await parse(text))),
       _validate =
           validate ?? ((text) => AppHostApi().testXray(text, buildOnly: true)),
       _write =
           write ?? ((rows) => ConfigWriter.writeRowsWithResult(rows, null)),
       _schedule = schedule ?? PingService().schedulePingConfigIds,
       _subscribe = subscribe ?? _importSubscription,
       _validateGeoData =
           validateGeoData ??
           ((link) async =>
               (await GeoDataValidator.validate(link.name, link.url)).item1),
       _writeGeoData =
           writeGeoData ??
           ((link) => GeoDataService().insertGeoDat(
             link.name,
             link.type,
             link.url,
             showLoading: false,
           ));

  static void _checkSize(String text) {
    if (text.trim().isEmpty || utf8.encode(text).length > 16 * 1024 * 1024) {
      throw const FormatException('Invalid import size');
    }
  }

  /// Classify before any writes. JSON/YAML/base64 stay intact for the native parser.
  ServerImportDetection detect(String text) {
    _checkSize(text);
    if (_structuredInput(text)) return ServerImportDetection(const [], text);
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
  ) async {
    final results = <ServerSubscriptionImport>[];
    for (final link in links) {
      final name = link.name.trim().isEmpty
          ? Uri.parse(link.url).host
          : link.name.trim();
      try {
        results.add(ServerSubscriptionImport(name, await _subscribe(link)));
      } catch (_) {
        results.add(
          ServerSubscriptionImport(
            name,
            const SubscriptionInsertResult(
              status: SubscriptionUpdateResult.writeFailed,
            ),
          ),
        );
      }
    }
    return List.unmodifiable(results);
  }

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
      final result = await service.refreshSubscriptionResult(row, false);
      return SubscriptionInsertResult(
        status: result.status,
        subId: row.id,
        count: result.count,
        parseFailureCount: result.parseFailureCount,
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
      false,
    );
  }

  Future<ServerImportPreview> preview(
    String text, {
    bool manual = false,
  }) async {
    _checkSize(text);
    if (!manual) {
      if (_structuredInput(text)) {
        final report = await _parse(text);
        return ServerImportPreview(
          report.rows,
          failureCount: report.failureCount,
        );
      }
      final rows = <CoreConfigCompanion>[];
      final geoData = <OneXrayGeoDataLink>[];
      final other = <String>[];
      int? failed = 0;
      for (final line in text.split('\n')) {
        final uri = Uri.tryParse(line.trim());
        final link = uri == null ? null : OneXrayAppLinkParser.parse(uri);
        if (link == null) {
          if (uri?.scheme.toLowerCase() == OneXrayAppLinkParser.scheme) {
            failed = failed! + 1;
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
            requireCanonicalOutbound(outbound);
            final error = await _validate(
              jsonEncode({
                'outbounds': [outbound],
              }),
            );
            if (error.isNotEmpty) {
              throw const FormatException('Invalid outbound');
            }
            rows.add(outboundCompanion(outbound));
          } else if (link is OneXrayConfigLink &&
              link.type == OneXrayConfigLinkType.raw) {
            final json = jsonDecode(link.xrayJson);
            final name = link.name.isNotEmpty ? link.name : json['name'];
            if (name is! String) {
              throw const FormatException('Raw needs a name');
            }
            final text = RawEditorService.namedText(name, link.xrayJson);
            final checked = await XrayRawValidator.validate(
              text,
              testXray: _validate,
            );
            if (!checked.isValid) throw const FormatException('Invalid Raw');
            rows.add(XrayRawDb.configCompanion(name, text));
          } else if (link is OneXrayGeoDataLink) {
            if (!_safeGeoDataName(link.name) ||
                !NetClient.isHttpsDownloadUri(Uri.parse(link.url)) ||
                !await _validateGeoData(link) ||
                geoData.any((item) => item.name == link.name)) {
              throw const FormatException('Invalid data source');
            }
            geoData.add(link);
          } else {
            throw const FormatException('Unsupported local asset');
          }
        } catch (_) {
          failed = failed! + 1;
        }
      }
      if (other.any((line) => line.trim().isNotEmpty)) {
        try {
          final report = await _parse(other.join('\n'));
          rows.addAll(report.rows);
          failed = report.failureCount == null
              ? null
              : failed! + report.failureCount!;
        } catch (_) {
          // An unsupported container has no reliable item count.
          failed = null;
        }
      }
      return ServerImportPreview(rows, geoData: geoData, failureCount: failed);
    }
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> ||
        json['outbounds'] is! List ||
        (json['outbounds'] as List).isEmpty) {
      throw const FormatException('A non-empty outbounds array is required');
    }
    final rows = <CoreConfigCompanion>[];
    final tags = <String>{};
    for (final outbound in json['outbounds'] as List) {
      if (outbound is! Map<String, dynamic> ||
          outbound['tag'] is! String ||
          (outbound['tag'] as String).trim().isEmpty ||
          !tags.add(outbound['tag'] as String) ||
          outbound['protocol'] is! String ||
          (outbound['protocol'] as String).trim().isEmpty) {
        throw const FormatException(
          'Every outbound needs a unique tag and protocol',
        );
      }
      requireCanonicalOutbound(outbound);
      rows.add(outboundCompanion(outbound));
    }
    final error = await _validate(jsonEncode({'outbounds': json['outbounds']}));
    if (error.isNotEmpty) {
      // Do not display native errors containing imported credentials.
      throw const FormatException('Invalid Xray node JSON');
    }
    return ServerImportPreview(rows, failureCount: 0);
  }

  Future<ServerImportResult> commit(ServerImportPreview preview) async {
    if (!preview.hasItems) {
      throw const FormatException('No usable servers');
    }
    if (preview.rows.isNotEmpty) {
      final result = await _write(preview.rows);
      if (result.count != preview.rows.length ||
          result.ids.length != preview.rows.length) {
        throw StateError('Incomplete asset write');
      }
      _schedule([
        for (var index = 0; index < result.ids.length; index++)
          if (preview.rows[index].type.value == 'outbound') result.ids[index],
      ]);
    }
    var geoDataCount = 0;
    final failures = <OneXrayGeoDataLink>[];
    for (final link in preview.geoData) {
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
      geoDataCount: geoDataCount,
      failedGeoData: List.unmodifiable(failures),
      failureCount: preview.failureCount,
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

  static bool _structuredInput(String text) =>
      text.trimLeft().startsWith('{') ||
      RegExp(r'^proxies\s*:', multiLine: true).hasMatch(text);

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
          : ['json', 'txt', 'yaml', 'yml', 'png', 'jpg', 'jpeg', 'webp'],
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
