import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/tun_setting/state.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:onexray/service/xray/setting/log_state.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/tun_route.dart';

class XrayRawFix {
  static Future<void> fixConfig(
    Map<String, dynamic> jsonMap,
    TunSettingState tunSettingState,
    XrayPorts ports,
    bool metricsEnabled,
  ) async {
    final disableLog = await AppHostApi().useSystemExtension();

    fixInboundsPort(jsonMap, ports);
    fixLog(jsonMap, disableLog: disableLog);
    fixMetrics(jsonMap, metricsEnabled ? ports.metricsPort : null);
    if (!metricsEnabled) {
      ports.metricsPort = "";
    }

    if (AppPlatform.isWindows || AppPlatform.isLinux) {
      _removeConfigInterface(jsonMap);
      _applyRawTunRouteConfig(
        jsonMap,
        XrayTunRouteConfig.fromTunSetting(tunSettingState),
      );
    } else {
      _removeConfigInterface(jsonMap);
    }
  }

  static void _removeConfigInterface(Map<String, dynamic> jsonMap) {
    final List<dynamic>? outbounds = jsonMap["outbounds"];
    if (outbounds != null) {
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

    final List<dynamic>? inbounds = jsonMap["inbounds"];
    if (inbounds == null) {
      return;
    }
    for (final inbound in inbounds) {
      if (inbound["tag"] == RoutingInboundTag.tunIn.name &&
          inbound["protocol"] == XrayInboundProtocol.tun.name) {
        final settings = inbound["settings"];
        if (settings is Map) {
          XrayTunRouteConfig.removeFromRawTunSettings(settings);
        }
        return;
      }
    }
  }

  static void _applyRawTunRouteConfig(
    Map<String, dynamic> jsonMap,
    XrayTunRouteConfig config,
  ) {
    final List<dynamic>? inbounds = jsonMap["inbounds"];
    if (inbounds == null) {
      return;
    }
    for (final inbound in inbounds) {
      if (inbound["tag"] == RoutingInboundTag.tunIn.name &&
          inbound["protocol"] == XrayInboundProtocol.tun.name) {
        final settings = inbound["settings"];
        if (settings is Map<String, dynamic>) {
          config.applyToRawTunSettings(settings);
        } else if (settings is Map) {
          final newSettings = Map<String, dynamic>.from(settings);
          config.applyToRawTunSettings(newSettings);
          inbound["settings"] = newSettings;
        } else {
          final newSettings = <String, dynamic>{};
          config.applyToRawTunSettings(newSettings);
          inbound["settings"] = newSettings;
        }
        return;
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
    final inbounds = _ensureList(jsonMap, "inbounds");
    inbounds.removeWhere(_isPingInbound);

    final pingInbound = InboundPingState()
      ..port = ports.pingPort
      ..auth = ports.pingAuth;
    inbounds.add(pingInbound.xrayJson.toJson());

    _fixPingRoutingRule(jsonMap);
  }

  static bool _isPingInbound(dynamic inbound) {
    return inbound is Map && inbound["tag"] == RoutingInboundTag.pingIn.name;
  }

  static void _fixPingRoutingRule(Map<String, dynamic> jsonMap) {
    final routing = _ensureMap(jsonMap, "routing");
    final rules = _ensureList(routing, "rules");
    rules.removeWhere(_isPingRoutingRule);

    final outboundTag = _pingOutboundTag(jsonMap);
    if (outboundTag == null) {
      return;
    }
    rules.insert(0, <String, dynamic>{
      "inboundTag": <String>[RoutingInboundTag.pingIn.name],
      "outboundTag": outboundTag,
      "ruleTag": RoutingRuleTag.ping,
    });
  }

  static bool _isPingRoutingRule(dynamic rule) {
    if (rule is! Map) {
      return false;
    }
    if (rule["ruleTag"] == RoutingRuleTag.ping) {
      return true;
    }
    final inboundTag = rule["inboundTag"];
    if (inboundTag is List) {
      return inboundTag.contains(RoutingInboundTag.pingIn.name);
    }
    return inboundTag == RoutingInboundTag.pingIn.name;
  }

  static String? _pingOutboundTag(Map<String, dynamic> jsonMap) {
    final outbounds = jsonMap["outbounds"];
    if (outbounds is! List) {
      return null;
    }

    for (final outbound in outbounds) {
      if (outbound is Map && outbound["tag"] == RoutingOutboundTag.proxy.name) {
        return RoutingOutboundTag.proxy.name;
      }
    }

    for (final outbound in outbounds) {
      if (outbound is Map) {
        final tag = outbound["tag"];
        if (tag is String && tag.isNotEmpty) {
          return tag;
        }
      }
    }
    return null;
  }

  static Map<String, dynamic> _ensureMap(
    Map<String, dynamic> jsonMap,
    String key,
  ) {
    final value = jsonMap[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    final map = <String, dynamic>{};
    jsonMap[key] = map;
    return map;
  }

  static List<dynamic> _ensureList(Map<String, dynamic> jsonMap, String key) {
    final value = jsonMap[key];
    if (value is List) {
      return value;
    }
    final list = <dynamic>[];
    jsonMap[key] = list;
    return list;
  }

  static void fixMetrics(Map<String, dynamic> jsonMap, [String? metricsPort]) {
    jsonMap.remove("policy");
    jsonMap.remove("metrics");
    jsonMap.remove("stats");

    if (metricsPort == null || metricsPort.isEmpty) {
      return;
    }

    jsonMap["stats"] = <String, dynamic>{};
    jsonMap["policy"] = <String, dynamic>{
      "system": <String, dynamic>{
        "statsInboundUplink": true,
        "statsInboundDownlink": true,
        "statsOutboundUplink": true,
        "statsOutboundDownlink": true,
      },
    };
    jsonMap["metrics"] = <String, dynamic>{
      "listen": "${NetConstants.proxyHost}:$metricsPort",
    };
  }

  static void fixLog(Map<String, dynamic> jsonMap, {bool disableLog = false}) {
    if (disableLog) {
      jsonMap["log"] = <String, dynamic>{
        "loglevel": XrayLogLevel.none.name,
        "dnsLog": false,
      };
      return;
    }
    final Map<String, dynamic>? log = jsonMap["log"];
    if (log == null) {
      return;
    }
    log["access"] = XrayStateConstants.accessLogPath;
    log["error"] = XrayStateConstants.errorLogPath;
  }
}
