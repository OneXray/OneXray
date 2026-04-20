import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/setting/state_writer.dart';

extension XraySettingStateDb on XraySettingState {
  CoreConfigCompanion configCompanion() {
    final jsonData = JsonTool.encoderForDb.convert(xrayJson);
    final bytes = utf8.encode(jsonData);
    final base64Data = base64Encode(bytes);
    final row = CoreConfigCompanion.insert(
      name: name,
      type: CoreConfigType.setting.name,
      tags: "",
      data: Value<String>(base64Data),
      delay: PingDelayConstants.unknown,
      subId: DBConstants.defaultId,
    );
    return row;
  }

  Future<int> insertToDb() async {
    final db = AppDatabase();
    final newRow = configCompanion();
    final res = await db.coreConfigDao.insertRow(newRow);
    return res;
  }

  Future<bool> updateToDb(CoreConfigData setting) async {
    final jsonData = JsonTool.encoderForDb.convert(xrayJson);
    final bytes = utf8.encode(jsonData);
    final base64Data = base64Encode(bytes);
    final row = setting.copyWith(name: name, data: Value<String>(base64Data));
    final db = AppDatabase();
    final res = await db.coreConfigDao.updateRow(row);
    return res;
  }
}
