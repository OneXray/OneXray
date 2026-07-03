import 'dart:convert';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/simple_state_writer.dart';
import 'package:onexray/service/xray/profile/state.dart';

extension XrayProfileStateReader on XrayProfileState {
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

  static Future<XrayProfileState> loadFromDb() async {
    var state = XrayProfileState();

    final id = await PreferencesKey().readXrayProfileId();
    switch (id) {
      case XrayProfileSimple.simpleId:
        final xrayProfileSimple = XrayProfileSimple();
        await xrayProfileSimple.readFromPreferences();
        state = xrayProfileSimple.xrayProfileState;
        break;
      default:
        final db = AppDatabase();
        final xrayProfileData = await db.coreConfigDao.searchRow(id);
        if (xrayProfileData != null && xrayProfileData.data != null) {
          state.readFromDbData(xrayProfileData);
        } else {
          await PreferencesKey().saveXrayProfileId(XrayProfileSimple.simpleId);
          final xrayProfileSimple = XrayProfileSimple();
          await xrayProfileSimple.readFromPreferences();
          state = xrayProfileSimple.xrayProfileState;
        }
        break;
    }
    return state;
  }
}
