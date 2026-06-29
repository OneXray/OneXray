import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/tun_setting/state.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:onexray/service/xray/setting/log_state.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/setting/state_reader.dart';
import 'package:onexray/service/xray/standard.dart';
import 'package:onexray/service/xray/tun_route.dart';

extension XraySettingStateWriter on XraySettingState {
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

  XraySettingState get copy {
    final copy = XraySettingState();
    copy.readFromXrayJson(xrayJson);
    return copy;
  }

  Future<XrayJson> fixSetting(
    TunSettingState tunSettingState,
    XrayPorts ports,
  ) async {
    fixInboundsPort(ports);
    await _fixSystemExtensionLogs();

    if (AppPlatform.isWindows || AppPlatform.isLinux) {
      _removeSettingInterface();
      _applyTunRouteConfig(tunSettingState);
    } else {
      _removeSettingInterface();
    }

    return _fixedXrayJson(ports, tunSettingState.metricsEnabled);
  }

  XrayJson _fixedXrayJson(XrayPorts ports, bool metricsEnabled) {
    final xrayJson = this.xrayJson;
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

  void _applyTunRouteConfig(TunSettingState tunSettingState) {
    final config = XrayTunRouteConfig.fromTunSetting(tunSettingState);
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
