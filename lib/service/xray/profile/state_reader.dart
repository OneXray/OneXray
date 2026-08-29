import 'dart:convert';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/profile/map.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/simple_state_writer.dart';

const defaultProfileMetrics = <String, dynamic>{'listen': '127.0.0.1:0'};
const defaultProfileStats = <String, dynamic>{};

Map<String, dynamic> readProfileMapFromDbData(CoreConfigData setting) {
  if (!EmptyTool.checkString(setting.data)) {
    throw const FormatException('Xray profile database data is empty');
  }
  final bytes = base64Decode(setting.data!);
  final text = utf8.decode(bytes);
  return readProfileMapFromText(text);
}

Map<String, dynamic> readProfileMapFromText(
  String text, {
  String nameOverride = '',
}) {
  final value = JsonTool.decoder.convert(text);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Xray JSON root must be an object');
  }
  if (nameOverride.isNotEmpty) {
    value['name'] = nameOverride;
  }
  validateXrayConfigMap(value);
  normalizeOutboundTags(value);
  return value;
}

String encodeProfileMap(Map<String, dynamic> profile) =>
    encodeXrayConfigMap(profile);

String profileName(Map<String, dynamic> profile) {
  final name = profile['name'];
  if (name is! String || name.trim().isEmpty) {
    throw const FormatException('Xray profile name is required');
  }
  return name;
}

Map<String, dynamic> newProfileMap(String defaultDnsServerAddress) {
  final map = createBaseProfileMap(dnsServerAddress: defaultDnsServerAddress);
  map['policy'] = <String, dynamic>{
    'system': <String, dynamic>{
      'statsInboundUplink': true,
      'statsInboundDownlink': true,
      'statsOutboundUplink': true,
      'statsOutboundDownlink': true,
    },
  };
  return copyXrayConfigMap(map);
}

Future<Map<String, dynamic>> loadSelectedProfileMap(
  TunSettingsState tunSettings,
) async {
  final id = await PreferencesKey().readXrayProfileId();
  if (id == XrayProfileSimple.simpleId) {
    return _loadSimpleProfileMap(tunSettings);
  }

  final xrayProfileData = await AppDatabase().coreConfigDao.searchRow(id);
  if (xrayProfileData != null && xrayProfileData.data != null) {
    return readProfileMapFromDbData(xrayProfileData);
  }

  await PreferencesKey().saveXrayProfileId(XrayProfileSimple.simpleId);
  return _loadSimpleProfileMap(tunSettings);
}

Future<Map<String, dynamic>> _loadSimpleProfileMap(
  TunSettingsState tunSettings,
) async {
  final simple = XrayProfileSimple();
  await simple.readFromPreferences();
  return copyXrayConfigMap(simple.xrayProfileMap(tunSettings.tunDnsIPv4));
}
