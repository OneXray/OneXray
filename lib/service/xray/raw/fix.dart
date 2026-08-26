import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/runtime_inbounds.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/log_state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/tun_route.dart';

class XrayRawFix {
  static Future<void> fixProfileConfig(
    Map<String, dynamic> jsonMap,
    XrayProfileState settingState,
    CoreRunMode mode,
    TunSettingsState tunSettingsState,
    XrayPorts ports,
    bool metricsEnabled, {
    bool? disableLog,
  }) async {
    final shouldDisableLog =
        disableLog ?? await AppHostApi().useSystemExtension();

    settingState.inbounds.ping.port = ports.pingPort;
    settingState.inbounds.ping.auth = ports.pingAuth;
    fixEnv(jsonMap);
    _fixDnsQueryStrategy(jsonMap, tunSettingsState);
    _applyProfileRuntimeInbounds(jsonMap, settingState.inbounds, mode);
    _fixPingRoutingRule(jsonMap, rejectConflicts: true);
    fixLog(jsonMap, disableLog: shouldDisableLog);
    if (metricsEnabled) {
      _applyProfileMetrics(jsonMap, ports.metricsPort);
    } else {
      ports.metricsPort = "";
    }

    if (mode == CoreRunMode.tun &&
        (AppPlatform.isWindows || AppPlatform.isLinux)) {
      _removeConfigInterface(jsonMap);
      _applyRawTunRouteConfig(
        jsonMap,
        XrayTunRouteConfig.fromTunSetting(tunSettingsState),
      );
    } else {
      _removeConfigInterface(jsonMap);
    }
  }

  static Future<void> fixConfig(
    Map<String, dynamic> jsonMap,
    XrayProfileState settingState,
    CoreRunMode mode,
    TunSettingsState tunSettingsState,
    XrayPorts ports,
    bool metricsEnabled,
  ) async {
    final disableLog = await AppHostApi().useSystemExtension();

    settingState.inbounds.ping.port = ports.pingPort;
    settingState.inbounds.ping.auth = ports.pingAuth;
    fixEnv(jsonMap);
    _fixDnsQueryStrategy(jsonMap, tunSettingsState);
    XrayRuntimeInbounds.applyToRawJson(jsonMap, settingState.inbounds, mode);
    _fixPingRoutingRule(jsonMap);
    fixLog(jsonMap, disableLog: disableLog);
    fixMetrics(jsonMap, metricsEnabled ? ports.metricsPort : null);
    if (!metricsEnabled) {
      ports.metricsPort = "";
    }

    if (mode == CoreRunMode.tun &&
        (AppPlatform.isWindows || AppPlatform.isLinux)) {
      _removeConfigInterface(jsonMap);
      _applyRawTunRouteConfig(
        jsonMap,
        XrayTunRouteConfig.fromTunSetting(tunSettingsState),
      );
    } else {
      _removeConfigInterface(jsonMap);
    }
  }

  static void fixEnv(Map<String, dynamic> jsonMap) {
    jsonMap["env"] = XrayEnv(
      assetLocation: VpnConstants.datDir,
      certLocation: VpnConstants.datDir,
    ).toJson();
  }

  static void _fixDnsQueryStrategy(
    Map<String, dynamic> jsonMap,
    TunSettingsState tunSettingsState,
  ) {
    final dns = jsonMap["dns"];
    if (dns is! Map) {
      return;
    }
    final strategy = DnsQueryStrategy.fromTunSettings(tunSettingsState).name;
    dns["queryStrategy"] = strategy;

    final servers = dns["servers"];
    if (servers is! List) {
      return;
    }
    for (final server in servers) {
      if (server is Map) {
        server["queryStrategy"] = strategy;
      }
    }
  }

  static void _applyProfileRuntimeInbounds(
    Map<String, dynamic> jsonMap,
    InboundsState settingInbounds,
    CoreRunMode mode,
  ) {
    final existing = jsonMap['inbounds'];
    final inbounds = existing is List ? existing : const <dynamic>[];
    _requireCompatibleRuntimeInbound(
      inbounds,
      RoutingInboundTag.tunIn.name,
      XrayInboundProtocol.tun.name,
    );
    _requireCompatibleRuntimeInbound(
      inbounds,
      RoutingInboundTag.pingIn.name,
      XrayInboundProtocol.http.name,
    );

    final runtime = settingInbounds
        .runtimeXrayJson(mode)
        .map((inbound) => inbound.toJson())
        .toList();
    final ping = runtime.firstWhere(
      (inbound) => inbound['tag'] == RoutingInboundTag.pingIn.name,
    );
    final result = <dynamic>[
      ...inbounds.where(
        (inbound) =>
            inbound is! Map ||
            (inbound['tag'] != RoutingInboundTag.tunIn.name &&
                inbound['tag'] != RoutingInboundTag.pingIn.name),
      ),
    ];
    if (mode == CoreRunMode.proxy) {
      result.add(ping);
      jsonMap['inbounds'] = result;
      return;
    }

    Map<dynamic, dynamic>? existingTun;
    for (final inbound in inbounds.whereType<Map>()) {
      if (inbound['tag'] == RoutingInboundTag.tunIn.name) {
        existingTun = inbound;
        break;
      }
    }
    final generatedTun = runtime.firstWhere(
      (inbound) => inbound['tag'] == RoutingInboundTag.tunIn.name,
    );
    final tun = existingTun == null
        ? generatedTun
        : _mergeRuntimeTun(existingTun, generatedTun);
    result.insert(0, tun);
    result.add(ping);
    jsonMap['inbounds'] = result;
  }

  static Map<String, dynamic> _mergeRuntimeTun(
    Map<dynamic, dynamic> existing,
    Map<String, dynamic> generated,
  ) {
    final tun = Map<String, dynamic>.from(existing);
    for (final key in const ['listen', 'protocol', 'tag']) {
      tun[key] = generated[key];
    }
    final existingSettings = tun['settings'];
    final settings = existingSettings is Map
        ? Map<String, dynamic>.from(existingSettings)
        : <String, dynamic>{};
    final generatedSettings = generated['settings'] as Map<String, dynamic>;
    for (final key in const ['name', 'mtu']) {
      settings[key] = generatedSettings[key];
    }
    tun['settings'] = settings;
    return tun;
  }

  static void _requireCompatibleRuntimeInbound(
    List<dynamic> inbounds,
    String tag,
    String protocol,
  ) {
    final matches = inbounds
        .whereType<Map>()
        .where((inbound) => inbound['tag'] == tag)
        .toList();
    if (matches.length > 1 ||
        (matches.isNotEmpty && matches.single['protocol'] != protocol)) {
      throw FormatException('Reserved inbound $tag is invalid');
    }
  }

  static void _removeConfigInterface(Map<String, dynamic> jsonMap) {
    final List<dynamic>? outbounds = jsonMap["outbounds"];
    if (outbounds != null) {
      for (final outbound in outbounds) {
        if (outbound is! Map) {
          continue;
        }
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
      if (inbound is! Map) {
        continue;
      }
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
      if (inbound is! Map) {
        continue;
      }
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

  static void keepOnlyPingInbound(
    Map<String, dynamic> jsonMap, {
    XrayPorts? ports,
  }) {
    jsonMap["inbounds"] = [_pingInbound(ports).toJson()];
    _fixPingRoutingRule(jsonMap);
  }

  static void prepareProfileValidationConfig(Map<String, dynamic> jsonMap) {
    _applyProfileRuntimeInbounds(jsonMap, InboundsState(), CoreRunMode.tun);
    _fixPingRoutingRule(jsonMap, rejectConflicts: true);
    fixEnv(jsonMap);
  }

  static void fixInboundsPort(Map<String, dynamic> jsonMap, XrayPorts ports) {
    final inbounds = _ensureList(jsonMap, "inbounds");
    inbounds.removeWhere(_isPingInbound);

    inbounds.add(_pingInbound(ports).toJson());

    _fixPingRoutingRule(jsonMap);
  }

  static XrayInbound _pingInbound(XrayPorts? ports) {
    final pingInbound = InboundPingState();
    if (ports != null) {
      pingInbound.port = ports.pingPort;
      pingInbound.auth = ports.pingAuth;
    }
    return pingInbound.xrayJson;
  }

  static bool _isPingInbound(dynamic inbound) {
    return inbound is Map && inbound["tag"] == RoutingInboundTag.pingIn.name;
  }

  static void _fixPingRoutingRule(
    Map<String, dynamic> jsonMap, {
    bool rejectConflicts = false,
  }) {
    final routing = _ensureMap(jsonMap, "routing");
    final rules = _ensureList(routing, "rules");
    if (rejectConflicts) {
      final reserved = rules.where(_isPingRoutingRule).toList();
      if (reserved.length > 1 ||
          (reserved.isNotEmpty &&
              !_isCompatiblePingRoutingRule(reserved.single))) {
        throw const FormatException('Reserved ping routing rule is invalid');
      }
    }
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

  static bool _isCompatiblePingRoutingRule(dynamic rule) {
    if (rule is! Map || rule['ruleTag'] != RoutingRuleTag.ping) {
      return false;
    }
    final inboundTag = rule['inboundTag'];
    if (inboundTag is! List ||
        inboundTag.length != 1 ||
        inboundTag.single != RoutingInboundTag.pingIn.name) {
      return false;
    }
    final outboundTag = rule['outboundTag'];
    if (outboundTag is! String || outboundTag.isEmpty) {
      return false;
    }
    final type = rule['type'];
    if (type != null && type != 'field') {
      return false;
    }
    return rule.keys.every(
      const {'type', 'inboundTag', 'outboundTag', 'ruleTag'}.contains,
    );
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

  static void _applyProfileMetrics(
    Map<String, dynamic> jsonMap,
    String metricsPort,
  ) {
    final stats = jsonMap['stats'];
    if (stats is! Map<String, dynamic>) {
      jsonMap['stats'] = <String, dynamic>{};
    }

    final policy = _ensureMap(jsonMap, 'policy');
    final currentSystem = policy['system'];
    final system = currentSystem is Map<String, dynamic>
        ? currentSystem
        : <String, dynamic>{};
    system.addAll(<String, dynamic>{
      'statsInboundUplink': true,
      'statsInboundDownlink': true,
      'statsOutboundUplink': true,
      'statsOutboundDownlink': true,
    });
    policy['system'] = system;

    final metrics = _ensureMap(jsonMap, 'metrics');
    metrics['listen'] = '${NetConstants.proxyHost}:$metricsPort';
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
