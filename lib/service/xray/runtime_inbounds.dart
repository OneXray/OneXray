import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';

abstract final class XrayRuntimeInbounds {
  static void applyToXrayJson(
    XrayJson xrayJson,
    InboundsState inbounds,
    CoreRunMode mode,
  ) {
    switch (mode) {
      case CoreRunMode.tun:
        xrayJson.inbounds = <XrayInbound>[
          inbounds.tun.xrayJson,
          inbounds.ping.xrayJson,
        ];
      case CoreRunMode.proxy:
        xrayJson.inbounds?.removeWhere(
          (inbound) => inbound.protocol == XrayInboundProtocol.tun.name,
        );
    }
  }

  static void applyToRawJson(
    Map<String, dynamic> jsonMap,
    InboundsState inbounds,
    CoreRunMode mode,
  ) {
    switch (mode) {
      case CoreRunMode.tun:
        jsonMap["inbounds"] = <XrayInbound>[
          inbounds.tun.xrayJson,
          inbounds.ping.xrayJson,
        ].map((inbound) => inbound.toJson()).toList();
      case CoreRunMode.proxy:
        final rawInbounds = jsonMap["inbounds"];
        if (rawInbounds is List) {
          rawInbounds.removeWhere(
            (inbound) =>
                inbound is Map &&
                inbound["protocol"] == XrayInboundProtocol.tun.name,
          );
        }
    }
  }
}
