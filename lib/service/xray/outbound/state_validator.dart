import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/json_writer.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:tuple/tuple.dart';

Tuple2<bool, String> validateOutboundFields(
  Map<String, dynamic> outbound, {
  String? databaseName,
}) {
  if (outboundDisplayName(outbound, fallback: databaseName).isEmpty) {
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
  Map<String, dynamic> outbound, {
  String? databaseName,
}) async {
  final fields = validateOutboundFields(outbound, databaseName: databaseName);
  if (!fields.item1) {
    return fields;
  }
  final xrayJson = XrayJsonStandard.standard;
  final pingInbound = InboundPingState()
    ..port = '${NetConstants.defaultPingPort}';
  xrayJson.inbounds = [pingInbound.xrayJson];
  xrayJson.outbounds = [copyOutboundMap(outbound)];
  final error = await xrayJson.test();
  return error.isEmpty ? const Tuple2(true, '') : Tuple2(false, error);
}
