import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_reader.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_validator.dart';

CoreConfigCompanion multiNodeOutboundCompanion(Map<String, dynamic> config) =>
    CoreConfigCompanion.insert(
      name: multiNodeOutboundName(config),
      type: CoreConfigType.multiNodeOutbound.name,
      tags: '',
      data: Value<String>(_encodeMultiNodeOutbound(config)),
      delay: PingDelayConstants.unknown,
      subId: DBConstants.defaultId,
    );

Future<int> insertMultiNodeOutbound(Map<String, dynamic> config) =>
    AppDatabase().coreConfigDao.insertRow(multiNodeOutboundCompanion(config));

Future<bool> updateMultiNodeOutbound(
  Map<String, dynamic> config,
  CoreConfigData existing,
) => AppDatabase().coreConfigDao.updateRow(
  existing.copyWith(
    name: multiNodeOutboundName(config),
    data: Value<String>(_encodeMultiNodeOutbound(config)),
  ),
);

String _encodeMultiNodeOutbound(Map<String, dynamic> config) {
  final validation = validateMultiNodeOutboundFields(config);
  if (!validation.item1) {
    throw FormatException(validation.item2);
  }
  return base64Encode(utf8.encode(encodeMultiNodeOutboundMap(config)));
}
