import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/outbound/state_normalizer.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';

class XrayShareReader {
  Future<List<CoreConfigCompanion>> parseShareFile(String filePath) async {
    final file = File(filePath);
    final text = await file.readAsString();
    await FileTool.deleteFileIfExists(filePath);
    return parseShareText(text);
  }

  Future<List<CoreConfigCompanion>> parseOutboundShareText(
    String text, {
    String? ageSecretKey,
  }) async {
    final xrayJson = await AppHostApi().convertShareLinksToXrayJsonStrict(
      text,
      ageSecretKey: ageSecretKey,
    );
    return readXrayJsonOutbounds(xrayJson);
  }

  Future<List<CoreConfigCompanion>> parseShareText(String text) async {
    return parseOutboundShareText(text);
  }

  @visibleForTesting
  Future<List<CoreConfigCompanion>> readXrayJsonOutbounds(
    XrayJson xrayJson,
  ) async {
    final res = <CoreConfigCompanion>[];
    final outbounds = xrayJson.outbounds;
    if (outbounds == null) {
      return res;
    }

    for (var index = 0; index < outbounds.length; index++) {
      if (index > 0 && index % 64 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final outbound = outbounds[index];
      try {
        final state = OutboundState();
        final success = state.readFromOutbound(outbound);
        if (!success) {
          continue;
        }
        state.removeWhitespace();
        res.add(state.outboundCompanion);
      } catch (error, stackTrace) {
        ygLogger(
          "Failed to read imported outbound (${error.runtimeType})\n$stackTrace",
        );
      }
    }
    return res;
  }
}
