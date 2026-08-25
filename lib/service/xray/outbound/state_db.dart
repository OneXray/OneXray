import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/service/xray/outbound/map.dart';

Map<String, dynamic> readOutboundFromDbData(CoreConfigData row) {
  final data = row.data;
  if (data == null || data.isEmpty) {
    throw const FormatException('Outbound database data is empty');
  }
  return decodeSingleOutbound(utf8.decode(base64Decode(data)));
}

CoreConfigCompanion outboundCompanion(
  Map<String, dynamic> outbound, {
  String? databaseName,
}) {
  final saved = copyOutboundMap(outbound);
  requireCanonicalOutbound(saved);
  final name = outboundDisplayName(saved, fallback: databaseName);
  if (outboundString(saved, 'name')?.isNotEmpty != true && name.isNotEmpty) {
    saved['name'] = name;
  }
  return CoreConfigCompanion.insert(
    name: name,
    type: CoreConfigType.outbound.name,
    tags: outboundTags(saved),
    data: Value(base64Encode(utf8.encode(encodeSingleOutbound(saved)))),
    delay: PingDelayConstants.unknown,
    subId: DBConstants.defaultId,
  );
}

Future<int> insertOutboundToDb(Map<String, dynamic> outbound) =>
    AppDatabase().coreConfigDao.insertRow(outboundCompanion(outbound));

Future<bool> updateOutboundToDb(
  Map<String, dynamic> outbound,
  CoreConfigData row,
) async {
  final companion = outboundCompanion(outbound, databaseName: row.name);
  final saved = row.copyWith(
    name: companion.name.value,
    tags: companion.tags.value,
    data: companion.data,
  );
  return AppDatabase().coreConfigDao.updateRow(saved);
}
