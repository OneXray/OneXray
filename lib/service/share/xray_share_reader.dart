import 'package:flutter/foundation.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';

class ShareParseReport {
  final List<CoreConfigCompanion> rows;
  final int? failureCount;
  const ShareParseReport(this.rows, {this.failureCount});
  int get count => rows.length;
}

class XrayShareReader {
  Future<ShareParseReport> parseShareTextReport(
    String text, {
    String? ageSecretKey,
  }) async {
    final report = await AppHostApi().convertShareLinksToXrayJsonReport(
      text,
      ageSecretKey: ageSecretKey,
    );
    final rows = await readXrayJsonOutbounds(report.config);
    if (report.usableCount != null && rows.length > report.usableCount!) {
      throw const FormatException('Import counts differ from content');
    }
    return ShareParseReport(
      rows,
      failureCount: report.failedCount == null || report.usableCount == null
          ? null
          : report.failedCount! + report.usableCount! - rows.length,
    );
  }

  @visibleForTesting
  Future<List<CoreConfigCompanion>> readXrayJsonOutbounds(
    Map<String, dynamic> xrayJson,
  ) async {
    final res = <CoreConfigCompanion>[];
    final outbounds = xrayJson['outbounds'];
    if (outbounds is! List<dynamic>) {
      return res;
    }

    for (var index = 0; index < outbounds.length; index++) {
      if (index > 0 && index % 64 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final value = outbounds[index];
      if (value is! Map<String, dynamic>) {
        continue;
      }
      final outbound = copyOutboundMap(value);
      try {
        requireCanonicalOutbound(outbound);
        res.add(outboundCompanion(outbound));
      } catch (error, stackTrace) {
        ygLogger(
          "Failed to read imported outbound (${error.runtimeType})\n$stackTrace",
        );
      }
    }
    return res;
  }
}
