import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/raw/fix.dart';
import 'package:tuple/tuple.dart';

Tuple2<bool, String> validateOutboundFields(Map<String, dynamic> outbound) {
  if (outboundString(outbound, 'tag')?.isNotEmpty != true) {
    return Tuple2(false, appLocalizationsNoContext().validationNameRequired);
  }
  try {
    requireCanonicalOutbound(outbound);
  } on FormatException catch (error) {
    return Tuple2(false, error.message);
  }
  return const Tuple2(true, '');
}

Future<Tuple2<bool, String>> validateOutbound(
  Map<String, dynamic> outbound,
) async {
  final fields = validateOutboundFields(outbound);
  if (!fields.item1) {
    return fields;
  }
  final jsonMap = <String, dynamic>{
    'inbounds': <dynamic>[
      createPingInboundMap(port: '${NetConstants.defaultPingPort}'),
    ],
    'outbounds': <dynamic>[copyOutboundMap(outbound)],
  };
  XrayRawFix.fixEnv(jsonMap);
  await FileTool.checkDir(VpnConstants.runDir);
  final error = await AppHostApi().testXray(
    JsonTool.encodeJsonToSortedString(jsonMap),
  );
  return error.isEmpty ? const Tuple2(true, '') : Tuple2(false, error);
}
