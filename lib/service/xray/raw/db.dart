import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/tools/empty.dart';

class XrayRawDb {
  static String readFromDbData(CoreConfigData config) {
    if (EmptyTool.checkString(config.data)) {
      final bytes = base64Decode(config.data!);
      final text = utf8.decode(bytes);
      return text;
    }
    return "";
  }

  static CoreConfigCompanion configCompanion(String name, String rawText) {
    final bytes = utf8.encode(rawText);
    final base64Data = base64Encode(bytes);
    final row = CoreConfigCompanion.insert(
      name: name,
      type: CoreConfigType.raw.name,
      tags: "",
      data: Value<String>(base64Data),
      delay: PingDelayConstants.unknown,
      subId: DBConstants.defaultId,
    );
    return row;
  }

  static Future<int> insertToDb(String name, String rawText) async {
    final db = AppDatabase();
    final newRow = configCompanion(name, rawText);
    final res = await db.coreConfigDao.insertRow(newRow);
    return res;
  }

  static Future<bool> updateToDb(
    String name,
    String rawText,
    CoreConfigData configData,
  ) async {
    final bytes = utf8.encode(rawText);
    final base64Data = base64Encode(bytes);
    final row = configData.copyWith(
      name: name,
      data: Value<String>(base64Data),
    );
    final db = AppDatabase();
    final res = await db.coreConfigDao.updateRow(row);
    return res;
  }
}
