import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/xray/config_map.dart';

Map<String, dynamic> readMultiNodeOutboundFromDbData(CoreConfigData config) {
  final data = config.data;
  if (data == null || data.isEmpty) {
    throw const FormatException('Multi-node Outbound data is empty');
  }
  return readMultiNodeOutboundFromText(utf8.decode(base64Decode(data)));
}

Map<String, dynamic> readMultiNodeOutboundFromText(
  String text, {
  String nameOverride = '',
}) {
  final value = JsonTool.decoder.convert(text);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Xray JSON root must be an object');
  }
  final config = value;
  if (nameOverride.isNotEmpty) {
    config['name'] = nameOverride;
  }
  validateMultiNodeOutboundMap(config);
  return config;
}

String encodeMultiNodeOutboundMap(Map<String, dynamic> config) {
  validateMultiNodeOutboundMap(config);
  return encodeXrayConfigMap(config);
}

String multiNodeOutboundName(Map<String, dynamic> config) {
  final name = config['name'];
  if (name is! String || name.trim().isEmpty) {
    throw const FormatException('Multi-node Outbound name is required');
  }
  return name;
}
