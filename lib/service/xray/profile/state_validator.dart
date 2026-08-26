import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/raw/fix.dart';
import 'package:tuple/tuple.dart';

Tuple2<bool, String> validateProfileFields(Map<String, dynamic> profile) {
  final name = profile['name'];
  if (name is! String || name.trim().isEmpty) {
    return Tuple2(false, appLocalizationsNoContext().validationNameRequired);
  }
  try {
    validateXrayConfigMap(profile);
  } on FormatException catch (error) {
    return Tuple2(false, error.message.toString());
  }

  final rawOutbounds = profile['outbounds'];
  if (rawOutbounds == null) {
    return const Tuple2(true, '');
  }
  for (final value in rawOutbounds as List<dynamic>) {
    if (value is! Map<String, dynamic>) {
      return const Tuple2(false, 'Outbound must be an object');
    }
    try {
      requireCanonicalOutbound(value);
    } on FormatException catch (error) {
      return Tuple2(false, error.message.toString());
    }
  }
  return const Tuple2(true, '');
}

Future<Tuple2<bool, String>> validateProfile(
  Map<String, dynamic> profile,
) async {
  final fields = validateProfileFields(profile);
  if (!fields.item1) {
    return fields;
  }

  final materialized = copyXrayConfigMap(profile);
  try {
    XrayRawFix.prepareProfileValidationConfig(materialized);
  } on FormatException catch (error) {
    return Tuple2(false, error.message.toString());
  }
  await FileTool.checkDir(VpnConstants.runDir);
  final error = await AppHostApi().testXray(
    JsonTool.encoder.convert(materialized),
  );
  return error.isEmpty ? const Tuple2(true, '') : Tuple2(false, error);
}
