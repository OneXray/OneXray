import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/full_config/state.dart';

extension XrayFullConfigStateReader on XrayFullConfigState {
  bool readFromDbData(CoreConfigData config) {
    if (EmptyTool.checkString(config.data)) {
      final bytes = base64Decode(config.data!);
      final text = utf8.decode(bytes);
      return readFromText(text);
    }
    return false;
  }

  bool readFromText(String text) {
    final jsonData = JsonTool.decoder.convert(text);
    final xrayJson = XrayJson.fromJson(jsonData);
    return readFromXrayJson(xrayJson);
  }

  bool readFromXrayJson(XrayJson xrayJson) {
    if (!outbounds.readFromXrayJson(xrayJson)) {
      return false;
    }
    if (EmptyTool.checkString(xrayJson.name)) {
      name = xrayJson.name!;
    }
    routing.readFromXrayJson(xrayJson);
    dns.readFromXrayJson(xrayJson);
    return true;
  }
}
