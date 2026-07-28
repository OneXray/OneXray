import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';

abstract final class XrayRuntimeInbounds {
  static void applyToXrayJson(
    XrayJson xrayJson,
    InboundsState inbounds,
    CoreRunMode mode,
  ) {
    xrayJson.inbounds = inbounds.runtimeXrayJson(mode);
  }

  static void applyToRawJson(
    Map<String, dynamic> jsonMap,
    InboundsState inbounds,
    CoreRunMode mode,
  ) {
    jsonMap["inbounds"] = inbounds
        .runtimeXrayJson(mode)
        .map((inbound) => inbound.toJson())
        .toList();
  }
}
