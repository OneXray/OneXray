import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/tun_setting/state.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:onexray/service/xray/setting/log_state.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/setting/state_reader.dart';
import 'package:onexray/service/xray/standard.dart';

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
    xrayJson.policy = policy.xrayJson;
    xrayJson.stats = stats.xrayJson;
    xrayJson.metrics = metrics.xrayJson;

    return xrayJson;
  }

  XraySettingState get copy {
    final copy = XraySettingState();
    copy.readFromXrayJson(xrayJson);
    return copy;
  }

  Future<void> fixSetting(
    TunSettingState tunSettingState,
    XrayPorts ports,
  ) async {
    //fix interface
    if (tunSettingState.shouldFixInterface) {
      final networkInterface = await tunSettingState.networkInterface;
      if (networkInterface == null) {
        return;
      }
      _fixSettingInterface(networkInterface);
      tunSettingState.bindInterface = networkInterface;
    } else {
      _removeSettingInterface();
      tunSettingState.bindInterface = "";
    }

    fixInboundsPort(ports);
    fixMetricsPort(ports);
    await _fixSystemExtensionLogs();
  }

  void _fixSettingInterface(String interface) {
    if (!EmptyTool.checkString(outbounds.freedom.interface)) {
      outbounds.freedom.interface = interface;
    }
    if (!EmptyTool.checkString(outbounds.fragment.interface)) {
      outbounds.fragment.interface = interface;
    }
    for (final outbound in outbounds.outbounds) {
      if (!EmptyTool.checkString(outbound.interface)) {
        outbound.interface = interface;
      }
    }
    if (!EmptyTool.checkString(inbounds.tun.settings.autoOutboundsInterface)) {
      inbounds.tun.settings.autoOutboundsInterface = interface;
    }
  }

  void _removeSettingInterface() {
    outbounds.freedom.interface = "";
    for (final outbound in outbounds.outbounds) {
      outbound.interface = "";
    }
  }

  void fixInboundsPort(XrayPorts ports) {
    if (inbounds.ping.port == VpnConstants.randomPort) {
      inbounds.ping.port = ports.pingPort;
    } else {
      ports.pingPort = inbounds.ping.port;
    }
  }

  void fixMetricsPort(XrayPorts ports) {
    metrics.listen = "${NetConstants.proxyHost}:${ports.metricsPort}";
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
