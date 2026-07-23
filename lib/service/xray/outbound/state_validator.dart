import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/json_writer.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:tuple/tuple.dart';

extension OutboundStateValidator on OutboundState {
  Future<Tuple2<bool, String>> validate() async {
    if (!EmptyTool.checkString(name)) {
      return Tuple2(false, appLocalizationsNoContext().validationNameRequired);
    }
    final xrayJson = XrayJsonStandard.standard;

    final pingInbound = InboundPingState();
    pingInbound.port = "${NetConstants.defaultPingPort}";

    xrayJson.inbounds = [pingInbound.xrayJson];
    xrayJson.outbounds = [this.xrayJson];

    final res = await xrayJson.test();
    if (res.isNotEmpty) {
      return Tuple2(false, res);
    }
    return const Tuple2(true, "");
  }
}
