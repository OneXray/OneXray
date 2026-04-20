import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
import 'package:onexray/service/xray/standard.dart';

extension OutboundStateDb on OutboundState {
  CoreConfigCompanion get outboundCompanion {
    final config = XrayJsonStandard.standard;
    config.outbounds = [xrayJson];
    final tags = [protocol.name, network.name, security.name].join(",");
    final jsonData = JsonTool.encoderForDb.convert(config);
    final bytes = utf8.encode(jsonData);
    final base64Data = base64Encode(bytes);
    final row = CoreConfigCompanion.insert(
      name: name,
      type: CoreConfigType.outbound.name,
      tags: tags,
      data: Value<String>(base64Data),
      delay: PingDelayConstants.unknown,
      subId: DBConstants.defaultId,
    );
    return row;
  }

  Future<int> insertToDb() async {
    final db = AppDatabase();
    final res = await db.coreConfigDao.insertRow(outboundCompanion);
    return res;
  }

  Future<bool> updateToDb(CoreConfigData outbound) async {
    final config = XrayJsonStandard.standard;
    config.outbounds = [xrayJson];
    final tags = [protocol.name, network.name, security.name].join(",");
    final jsonData = JsonTool.encoderForDb.convert(config);
    final bytes = utf8.encode(jsonData);
    final base64Data = base64Encode(bytes);
    final row = outbound.copyWith(
      name: name,
      tags: tags,
      data: Value<String>(base64Data),
    );
    final db = AppDatabase();
    final res = await db.coreConfigDao.updateRow(row);
    return res;
  }
}
