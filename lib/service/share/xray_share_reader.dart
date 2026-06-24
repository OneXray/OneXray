import 'dart:io';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/outbound/state_validator.dart';

class XrayShareReader {
  Future<List<CoreConfigCompanion>> parseShareFile(String filePath) async {
    final file = File(filePath);
    final text = await file.readAsString();
    await FileTool.deleteFileIfExists(filePath);
    return parseShareText(text);
  }

  Future<List<CoreConfigCompanion>> parseOutboundShareText(String text) async {
    final xrayJson = await AppHostApi().convertShareLinksToXrayJson(text);
    final rows = await _readXrayJsonOutbounds(xrayJson);
    return rows;
  }

  Future<List<CoreConfigCompanion>> parseShareText(String text) async {
    return parseOutboundShareText(text);
  }

  Future<List<CoreConfigCompanion>> _readXrayJsonOutbounds(
    XrayJson xrayJson,
  ) async {
    final res = <CoreConfigCompanion>[];
    final outbounds = xrayJson.outbounds;
    if (outbounds == null) {
      return res;
    }

    for (final outbound in outbounds) {
      final state = OutboundState();
      final success = state.readFromOutbound(outbound);
      if (success) {
        state.removeWhitespace();
        final check = await state.validate();
        if (check.item1) {
          res.add(state.outboundCompanion);
        } else {
          ygLogger("Invalid outbound state: ${check.item2}");
        }
      }
    }
    return res;
  }
}
