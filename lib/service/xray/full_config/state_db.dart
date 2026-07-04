import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_writer.dart';

extension XrayFullConfigStateDb on XrayFullConfigState {
  CoreConfigCompanion configCompanion() {
    final jsonData = JsonTool.encoder.convert(xrayJson);
    final bytes = utf8.encode(jsonData);
    final base64Data = base64Encode(bytes);
    return CoreConfigCompanion.insert(
      name: name,
      type: CoreConfigType.full.name,
      tags: "",
      data: Value<String>(base64Data),
      delay: PingDelayConstants.unknown,
      subId: DBConstants.defaultId,
    );
  }

  Future<int> insertToDb() async {
    final db = AppDatabase();
    return db.coreConfigDao.insertRow(configCompanion());
  }

  Future<bool> updateToDb(CoreConfigData config) async {
    final jsonData = JsonTool.encoder.convert(xrayJson);
    final bytes = utf8.encode(jsonData);
    final base64Data = base64Encode(bytes);
    final row = config.copyWith(name: name, data: Value<String>(base64Data));
    final db = AppDatabase();
    return db.coreConfigDao.updateRow(row);
  }
}
