import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/full_config/state.dart';

extension XrayFullConfigStateReader on XrayFullConfigState {
  void readFromDbData(CoreConfigData config) {
    if (EmptyTool.checkString(config.data)) {
      final bytes = base64Decode(config.data!);
      final text = utf8.decode(bytes);
      readFromText(text);
    }
  }

  void readFromText(String text) {
    final jsonData = JsonTool.decoder.convert(text);
    final xrayJson = XrayJson.fromJson(jsonData);
    readFromXrayJson(xrayJson);
  }

  void readFromXrayJson(XrayJson xrayJson) {
    if (EmptyTool.checkString(xrayJson.name)) {
      name = xrayJson.name!;
    }
    outbounds.readFromXrayJson(xrayJson);
    routing.readFromXrayJson(xrayJson);
    dns.readFromXrayJson(xrayJson);
  }
}
