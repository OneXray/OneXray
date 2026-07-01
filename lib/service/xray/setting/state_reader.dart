import 'dart:convert';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';
import 'package:onexray/service/xray/setting/simple_state_writer.dart';
import 'package:onexray/service/xray/setting/state.dart';

extension XraySettingStateReader on XraySettingState {
  void readFromDbData(CoreConfigData setting) {
    if (EmptyTool.checkString(setting.data)) {
      final bytes = base64Decode(setting.data!);
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
    log.readFromXrayJson(xrayJson);
    dns.readFromXrayJson(xrayJson);
    fakeDns.readFromXrayJson(xrayJson);
    routing.readFromXrayJson(xrayJson);
    inbounds.readFromXrayJson(xrayJson);
    outbounds.readFromXrayJson(xrayJson);
    metrics.readFromXrayJson(xrayJson);
  }

  static Future<XraySettingState> loadFromDb() async {
    var state = XraySettingState();

    final id = await PreferencesKey().readXraySettingId();
    switch (id) {
      case XraySettingSimple.simpleId:
        final xraySettingSimple = XraySettingSimple();
        await xraySettingSimple.readFromPreferences();
        state = xraySettingSimple.xraySettingState;
        break;
      default:
        final db = AppDatabase();
        final xraySettingData = await db.coreConfigDao.searchRow(id);
        if (xraySettingData != null && xraySettingData.data != null) {
          state.readFromDbData(xraySettingData);
        } else {
          await PreferencesKey().saveXraySettingId(XraySettingSimple.simpleId);
          final xraySettingSimple = XraySettingSimple();
          await xraySettingSimple.readFromPreferences();
          state = xraySettingSimple.xraySettingState;
        }
        break;
    }
    return state;
  }
}
