import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/app_link_parser.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';

class ServerImportResult {
  final int count;
  final int? subscriptionId;
  final int? failureCount;
  const ServerImportResult({
    required this.count,
    this.subscriptionId,
    this.failureCount,
  });
}

class ServerImportPreview {
  final List<CoreConfigCompanion> rows;
  final int? failureCount;
  ServerImportPreview(Iterable<CoreConfigCompanion> rows, {this.failureCount})
    : rows = List.unmodifiable(rows);
  int get count => rows.length;
}

/// Local detection is read-only. Only an explicit confirmation calls [commit].
class ServerImportService {
  final Future<List<CoreConfigCompanion>> Function(String) _parse;
  final Future<String> Function(String) _validate;
  final Future<ConfigWriteResult> Function(List<CoreConfigCompanion>) _write;
  final void Function(List<int>) _schedule;

  ServerImportService({
    Future<List<CoreConfigCompanion>> Function(String)? parse,
    Future<String> Function(String)? validate,
    Future<ConfigWriteResult> Function(List<CoreConfigCompanion>)? write,
    void Function(List<int>)? schedule,
  }) : _parse = parse ?? XrayShareReader().parseShareText,
       _validate =
           validate ?? ((text) => AppHostApi().testXray(text, buildOnly: true)),
       _write =
           write ?? ((rows) => ConfigWriter.writeRowsWithResult(rows, null)),
       _schedule = schedule ?? PingService().schedulePingConfigIds;

  Future<ServerImportPreview> preview(
    String text, {
    bool manual = false,
  }) async {
    if (text.trim().isEmpty || utf8.encode(text).length > 16 * 1024 * 1024) {
      throw const FormatException('Invalid import size');
    }
    if (!manual) {
      final rows = <CoreConfigCompanion>[];
      final other = <String>[];
      for (final line in text.split('\n')) {
        final uri = Uri.tryParse(line.trim());
        final link = uri == null ? null : OneXrayAppLinkParser.parse(uri);
        if (link is OneXrayConfigLink &&
            link.type == OneXrayConfigLinkType.outbound) {
          final outbound = decodeSingleOutbound(
            link.xrayJson,
            nameAlias: link.name,
          );
          requireCanonicalOutbound(outbound);
          rows.add(outboundCompanion(outbound));
        } else if (link != null) {
          throw const FormatException('Import this asset separately');
        } else {
          other.add(line);
        }
      }
      if (other.any((line) => line.trim().isNotEmpty)) {
        rows.addAll(await _parse(other.join('\n')));
      }
      if (rows.isEmpty || rows.any((row) => row.type.value != 'outbound')) {
        throw const FormatException('No usable servers');
      }
      // The current native converter does not report rejected-item counts.
      return ServerImportPreview(rows);
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
    if (preview.rows.isEmpty) {
      throw const FormatException('No usable servers');
    }
    final result = await _write(preview.rows);
    _schedule(result.ids);
    return ServerImportResult(
      count: result.count,
      failureCount: preview.failureCount,
    );
  }

  /// A subscription or Raw link opens its own confirmation form, never a write.
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
          : ['json', 'txt', 'yaml', 'yml'],
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
    return input.readAsString();
  }

  static Future<String?> readClipboard() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;
}
