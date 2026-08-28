import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/tun_route.dart';

enum XrayRuntimePlatform {
  windows,
  linux,
  other;

  static XrayRuntimePlatform get current {
    if (AppPlatform.isWindows) {
      return XrayRuntimePlatform.windows;
    }
    if (AppPlatform.isLinux) {
      return XrayRuntimePlatform.linux;
    }
    return XrayRuntimePlatform.other;
  }
}

class XrayRawFix {
  static void applySelectedOutbound(
    Map<String, dynamic> jsonMap,
    Map<String, dynamic> selectedOutbound, {
    Map<String, dynamic>? finalOutbound,
  }) {
    final current = jsonMap['outbounds'];
    final outbounds = current is List<dynamic> ? current : <dynamic>[];
    final finalOutboundCount = outbounds
        .where(
          (outbound) =>
              outbound is Map &&
              outbound['tag'] == RoutingOutboundTag.chainProxy.name,
        )
        .length;
    if (finalOutboundCount > 1) {
      throw const FormatException('Duplicate chainProxy outbounds');
    }
    outbounds.removeWhere((outbound) {
      if (outbound is! Map) {
        return false;
      }
      final tag = outbound['tag'];
      return tag == RoutingOutboundTag.proxy.name ||
          tag == RoutingOutboundTag.chainProxy.name;
    });

    final selected = copyOutboundMap(selectedOutbound);
    if (finalOutbound == null) {
      setOutboundTag(selected, RoutingOutboundTag.proxy.name);
      outbounds.insert(0, selected);
    } else {
      final finalCopy = copyOutboundMap(finalOutbound);
      setOutboundTag(selected, RoutingOutboundTag.chainProxy.name);
      removeOutboundDialerProxy(selected);
      setOutboundTag(finalCopy, RoutingOutboundTag.proxy.name);
      setOutboundDialerProxy(finalCopy, RoutingOutboundTag.chainProxy.name);
      outbounds.insertAll(0, <dynamic>[finalCopy, selected]);
    }
    jsonMap['outbounds'] = outbounds;
  }

  static Future<void> fixProfileConfig(
    Map<String, dynamic> jsonMap,
    CoreRunMode mode,
    TunSettingsState tunSettingsState,
    XrayPorts ports,
    bool metricsEnabled, {
    bool? disableLog,
    XrayRuntimePlatform? runtimePlatform,
  }) async {
    final shouldDisableLog =
        disableLog ?? await AppHostApi().useSystemExtension();
    final platform = runtimePlatform ?? XrayRuntimePlatform.current;

    fixEnv(jsonMap);
    _fixDnsQueryStrategy(jsonMap, tunSettingsState);
    _applyProfileRuntimeInbounds(jsonMap, ports, mode, platform);
    _fixPingRoutingRule(jsonMap, rejectConflicts: true);
    fixLog(jsonMap, disableLog: shouldDisableLog);
    if (metricsEnabled) {
      _applyProfileMetrics(jsonMap, ports.metricsPort);
    } else {
      ports.metricsPort = "";
    }

    _applyPlatformInterface(
      jsonMap,
      mode,
      tunSettingsState,
      platform,
      appOwnedOnly: true,
    );
  }

  static Future<void> fixConfig(
    Map<String, dynamic> jsonMap,
    Map<String, dynamic> profileMap,
    CoreRunMode mode,
    TunSettingsState tunSettingsState,
    XrayPorts ports,
    bool metricsEnabled, {
    bool? disableLog,
    XrayRuntimePlatform? runtimePlatform,
  }) async {
    final shouldDisableLog =
        disableLog ?? await AppHostApi().useSystemExtension();
    final platform = runtimePlatform ?? XrayRuntimePlatform.current;

    final profileCopy = copyXrayConfigMap(profileMap);
    if (mode == CoreRunMode.tun) {
      jsonMap['inbounds'] = profileCopy['inbounds'];
    } else {
      jsonMap.remove('inbounds');
    }
    fixEnv(jsonMap);
    _fixDnsQueryStrategy(jsonMap, tunSettingsState);
    _applyProfileRuntimeInbounds(jsonMap, ports, mode, platform);
    _fixPingRoutingRule(jsonMap);
    fixLog(jsonMap, disableLog: shouldDisableLog);
    fixMetrics(jsonMap, metricsEnabled ? ports.metricsPort : null);
    if (!metricsEnabled) {
      ports.metricsPort = "";
    }

    _applyPlatformInterface(jsonMap, mode, tunSettingsState, platform);
  }

  static void fixEnv(Map<String, dynamic> jsonMap) {
    jsonMap['env'] = <String, dynamic>{
      'xray.location.asset': VpnConstants.datDir,
      'xray.location.cert': VpnConstants.datDir,
    };
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
    XrayPorts? ports,
    CoreRunMode mode,
    XrayRuntimePlatform platform,
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

    final result = <dynamic>[
      ...inbounds.where(
        (inbound) =>
            inbound is! Map ||
            (inbound['tag'] != RoutingInboundTag.tunIn.name &&
                inbound['tag'] != RoutingInboundTag.pingIn.name),
      ),
    ];
    if (mode == CoreRunMode.proxy) {
      result.add(_pingInbound(ports));
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
    final generated = platform == XrayRuntimePlatform.windows
        ? createSocksInboundMap(ports!.socksPort)
        : createTunInboundMap();
    final inbound = existingTun == null
        ? generated
        : platform == XrayRuntimePlatform.windows
        ? _mergeRuntimeSocks(existingTun, generated)
        : _mergeRuntimeTun(existingTun, generated);
    result.insert(0, inbound);
    result.add(_pingInbound(ports));
    jsonMap['inbounds'] = result;
  }

  static Map<String, dynamic> _mergeRuntimeSocks(
    Map<dynamic, dynamic> existing,
    Map<String, dynamic> generated,
  ) {
    final socks = Map<String, dynamic>.from(existing);
    for (final key in const ['listen', 'port', 'protocol', 'settings', 'tag']) {
      socks[key] = generated[key];
    }
    socks['sniffing'] ??= generated['sniffing'];
    return socks;
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

  static void _applyPlatformInterface(
    Map<String, dynamic> jsonMap,
    CoreRunMode mode,
    TunSettingsState tunSettings,
    XrayRuntimePlatform platform, {
    bool appOwnedOnly = false,
  }) {
    if (mode != CoreRunMode.tun) {
      _removeConfigInterface(jsonMap, appOwnedOnly: appOwnedOnly);
      return;
    }
    switch (platform) {
      case XrayRuntimePlatform.windows:
        _bindEveryOutbound(jsonMap, tunSettings.outboundsInterface);
        return;
      case XrayRuntimePlatform.linux:
        _removeConfigInterface(jsonMap);
        _applyRawTunRouteConfig(
          jsonMap,
          XrayTunRouteConfig.fromTunSetting(tunSettings),
        );
        return;
      case XrayRuntimePlatform.other:
        _removeConfigInterface(jsonMap, appOwnedOnly: appOwnedOnly);
        return;
    }
  }

  static void _bindEveryOutbound(
    Map<String, dynamic> jsonMap,
    String interface,
  ) {
    if (interface.isEmpty) {
      throw const FormatException('Network interface is required');
    }
    final outbounds = jsonMap['outbounds'];
    if (outbounds is! List) {
      return;
    }
    for (final outbound in outbounds.whereType<Map>()) {
      final streamSettings = _ensureObject(outbound, 'streamSettings');
      final sockopt = _ensureObject(streamSettings, 'sockopt');
      sockopt['interface'] = interface;
    }
  }

  static Map<dynamic, dynamic> _ensureObject(
    Map<dynamic, dynamic> parent,
    String key,
  ) {
    final value = parent[key];
    if (value == null) {
      final result = <String, dynamic>{};
      parent[key] = result;
      return result;
    }
    if (value is! Map) {
      throw FormatException('$key must be an object');
    }
    return value;
  }

  static void _removeConfigInterface(
    Map<String, dynamic> jsonMap, {
    bool appOwnedOnly = false,
  }) {
    final List<dynamic>? outbounds = jsonMap["outbounds"];
    if (outbounds != null) {
      for (final outbound in outbounds) {
        if (outbound is! Map) {
          continue;
        }
        final tag = outbound["tag"];
        final protocol = outbound["protocol"];
        if (appOwnedOnly &&
            (protocol != XrayOutboundProtocol.freedom.name ||
                (tag != RoutingOutboundTag.direct.name &&
                    tag != RoutingOutboundTag.fragment.name))) {
          continue;
        }
        final streamSettings = outbound["streamSettings"];
        if (streamSettings is Map) {
          final sockopt = streamSettings["sockopt"];
          if (sockopt is Map) {
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
    jsonMap['inbounds'] = <dynamic>[_pingInbound(ports)];
    _fixPingRoutingRule(jsonMap);
  }

  static void prepareProfileValidationConfig(Map<String, dynamic> jsonMap) {
    _applyProfileRuntimeInbounds(
      jsonMap,
      null,
      CoreRunMode.tun,
      XrayRuntimePlatform.other,
    );
    _fixPingRoutingRule(jsonMap, rejectConflicts: true);
    fixEnv(jsonMap);
  }

  static Map<String, dynamic> _pingInbound(XrayPorts? ports) => ports == null
      ? createPingInboundMap()
      : createPingInboundMap(port: ports.pingPort, auth: ports.pingAuth);

  static void _fixPingRoutingRule(
    Map<String, dynamic> jsonMap, {
    bool rejectConflicts = false,
  }) {
    final routing = _ensureMap(jsonMap, "routing");
    final currentRules = routing["rules"];
    if (rejectConflicts && currentRules != null && currentRules is! List) {
      throw const FormatException('routing.rules must be an array');
    }
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
      final log = _ensureMap(jsonMap, "log");
      log.remove("access");
      log.remove("error");
      log.remove("maskAddress");
      log["loglevel"] = XrayLogLevel.none.name;
      log["dnsLog"] = false;
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
