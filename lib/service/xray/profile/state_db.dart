import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_validator.dart';

CoreConfigCompanion profileCompanion(Map<String, dynamic> profile) =>
    CoreConfigCompanion.insert(
      name: profileName(profile),
      type: CoreConfigType.profile.name,
      tags: '',
      data: Value<String>(_encodeProfile(profile)),
      delay: PingDelayConstants.unknown,
      subId: DBConstants.defaultId,
    );

Future<int> insertProfile(Map<String, dynamic> profile) =>
    AppDatabase().coreConfigDao.insertRow(profileCompanion(profile));

Future<bool> updateProfile(
  Map<String, dynamic> profile,
  CoreConfigData existing,
) => AppDatabase().coreConfigDao.updateRow(
  existing.copyWith(
    name: profileName(profile),
    data: Value<String>(_encodeProfile(profile)),
  ),
);

String _encodeProfile(Map<String, dynamic> profile) {
  final normalized = copyXrayConfigMap(profile);
  normalizeOutboundTags(normalized);
  final validation = validateProfileFields(normalized);
  if (!validation.item1) {
    throw FormatException(validation.item2);
  }
  return base64Encode(utf8.encode(encodeProfileMap(normalized)));
}
