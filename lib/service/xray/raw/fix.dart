import 'package:onexray/service/tun_setting/state.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';

class XrayRawFix {
  static Future<void> fixConfig(
    Map<String, dynamic> jsonMap,
    TunSettingState tunSettingState,
    XrayPorts ports,
  ) async {
    //fix interface
    if (tunSettingState.shouldFixInterface) {
      final networkInterface = await tunSettingState.networkInterface;
      if (networkInterface == null) {
        return;
      }
      _fixConfigInterface(jsonMap, networkInterface);
      tunSettingState.bindInterface = networkInterface;
    } else {
      _removeConfigInterface(jsonMap);
      tunSettingState.bindInterface = "";
    }

    fixInboundsTun(jsonMap);
    fixInboundsPort(jsonMap, ports);
    fixLog(jsonMap);
    fixMetrics(jsonMap);
  }

  static void _fixConfigInterface(
    Map<String, dynamic> jsonMap,
    String bindInterface,
  ) {
    final List<dynamic>? outbounds = jsonMap["outbounds"];
    if (outbounds == null) {
      return;
    }
    for (final outbound in outbounds) {
      final Map<String, dynamic>? streamSettings = outbound["streamSettings"];
      if (streamSettings != null) {
        final Map<String, dynamic>? sockopt = streamSettings["sockopt"];
        if (sockopt != null) {
          sockopt["interface"] = bindInterface;
        } else {
          streamSettings["sockopt"] = <String, dynamic>{
            "interface": bindInterface,
          };
        }
      } else {
        final sockopt = <String, dynamic>{"interface": bindInterface};
        outbound["streamSettings"] = <String, dynamic>{"sockopt": sockopt};
      }
    }
  }

  static void _removeConfigInterface(Map<String, dynamic> jsonMap) {
    final List<dynamic>? outbounds = jsonMap["outbounds"];
    if (outbounds == null) {
      return;
    }
    for (final outbound in outbounds) {
      final Map<String, dynamic>? streamSettings = outbound["streamSettings"];
      if (streamSettings != null) {
        final Map<String, dynamic>? sockopt = streamSettings["sockopt"];
        if (sockopt != null) {
          sockopt.remove("interface");
        }
      }
    }
  }

  static void fixInboundsTun(Map<String, dynamic> jsonMap) {
    final List<dynamic>? inbounds = jsonMap["inbounds"];
    if (inbounds == null) {
      return;
    }
    for (final inbound in inbounds) {
      if (inbound["tag"] == RoutingInboundTag.tunIn.name &&
          inbound["protocol"] == XrayInboundProtocol.tun.name) {
        inbounds.remove(inbound);
        return;
      }
    }
  }

  static void fixInboundsPort(Map<String, dynamic> jsonMap, XrayPorts ports) {
    final List<dynamic>? inbounds = jsonMap["inbounds"];
    if (inbounds == null) {
      return;
    }
    for (final inbound in inbounds) {
      if (inbound["tag"] == RoutingInboundTag.pingIn.name &&
          inbound["protocol"] == XrayInboundProtocol.http.name) {
        if (inbound["port"] != null) {
          if (inbound["port"] == VpnConstants.randomPort) {
            inbound["port"] = ports.pingPort;
          } else {
            ports.pingPort = inbound["port"];
          }
        }
      }
    }
  }

  static void fixMetrics(Map<String, dynamic> jsonMap) {
    //remove metrics
    jsonMap.remove("policy");
    jsonMap.remove("metrics");
    jsonMap.remove("stats");
  }

  static void fixLog(Map<String, dynamic> jsonMap) {
    final Map<String, dynamic>? log = jsonMap["log"];
    if (log == null) {
      return;
    }
    log["access"] = XrayStateConstants.accessLogPath;
    log["error"] = XrayStateConstants.errorLogPath;
  }
}
