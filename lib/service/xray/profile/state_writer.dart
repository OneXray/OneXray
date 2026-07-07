import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/runtime_inbounds.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/log_state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/service/xray/tun_route.dart';

extension XrayProfileStateWriter on XrayProfileState {
  XrayJson get xrayJson {
    final xrayJson = XrayJsonStandard.standard;
    xrayJson.name = name;

    xrayJson.log = log.xrayJson;
    xrayJson.dns = dns.xrayJson;
    xrayJson.fakeDns = fakeDns.xrayJson(dns.queryStrategy);
    xrayJson.routing = routing.xrayJson;
    xrayJson.inbounds = inbounds.xrayJson;
    xrayJson.outbounds = outbounds.xrayJson;

    return xrayJson;
  }

  XrayProfileState get copy {
    final copy = XrayProfileState();
    copy.readFromXrayJson(xrayJson);
    return copy;
  }

  Future<XrayJson> fixSetting(
    CoreRunMode mode,
    TunSettingsState tunSettingsState,
    XrayPorts ports,
  ) async {
    fixInboundsPort(ports);
    await _fixSystemExtensionLogs();

    if (mode == CoreRunMode.tun &&
        (AppPlatform.isWindows || AppPlatform.isLinux)) {
      _removeSettingInterface();
      _applyTunRouteConfig(tunSettingsState);
    } else {
      _removeSettingInterface();
    }

    return _fixedXrayJson(mode, ports, tunSettingsState.metricsEnabled);
  }

  XrayJson _fixedXrayJson(
    CoreRunMode mode,
    XrayPorts ports,
    bool metricsEnabled,
  ) {
    final xrayJson = this.xrayJson;
    XrayRuntimeInbounds.applyToXrayJson(xrayJson, inbounds, mode);
    fixMetricsConfig(xrayJson, ports, metricsEnabled);
    return xrayJson;
  }

  void _removeSettingInterface() {
    outbounds.freedom.interface = "";
    outbounds.fragment.interface = "";
    for (final outbound in outbounds.outbounds) {
      outbound.interface = "";
    }
    inbounds.tun.settings.autoOutboundsInterface = "";
    inbounds.tun.settings.gateway = [];
    inbounds.tun.settings.dns = [];
    inbounds.tun.settings.autoSystemRoutingTable = [];
  }

  void _applyTunRouteConfig(TunSettingsState tunSettingsState) {
    final config = XrayTunRouteConfig.fromTunSetting(tunSettingsState);
    inbounds.tun.settings.applyRouteConfig(config);
  }

  void fixInboundsPort(XrayPorts ports) {
    inbounds.ping.port = ports.pingPort;
    inbounds.ping.auth = ports.pingAuth;
  }

  void fixMetricsConfig(
    XrayJson xrayJson,
    XrayPorts ports,
    bool metricsEnabled,
  ) {
    if (!metricsEnabled) {
      metrics.listen = "";
      ports.metricsPort = "";
      removeMetricsConfig(xrayJson);
      return;
    }
    metrics.listen = "${NetConstants.proxyHost}:${ports.metricsPort}";
    xrayJson.policy = policy.xrayJson;
    xrayJson.stats = stats.xrayJson;
    xrayJson.metrics = metrics.xrayJson;
  }

  void removeTunInbound(XrayJson xrayJson) {
    xrayJson.inbounds?.removeWhere(
      (inbound) => inbound.tag == RoutingInboundTag.tunIn.name,
    );
  }

  void removeMetricsConfig(XrayJson xrayJson) {
    xrayJson.policy = null;
    xrayJson.stats = null;
    xrayJson.metrics = null;
  }

  Future<void> _fixSystemExtensionLogs() async {
    final useSystemExtension = await AppHostApi().useSystemExtension();
    if (AppPlatform.isMacOS && useSystemExtension) {
      log.access = "";
      log.error = "";
      log.logLevel = XrayLogLevel.none;
      log.dnsLog = false;
      log.maskAddress = XrayLogMaskAddress.none;
    }
  }
}
