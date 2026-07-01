import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/tun_setting/state.dart';

class XrayTunRouteConfig {
  static const _gatewayKey = "gateway";
  static const _dnsKey = "dns";
  static const _autoSystemRoutingTableKey = "autoSystemRoutingTable";
  static const _autoOutboundsInterfaceKey = "autoOutboundsInterface";

  static const tunIPv4Gateway = "198.18.0.1/15";
  static const tunIPv6Gateway = "fc00::1/64";
  static const tunIPv4Route = "0.0.0.0/0";
  static const tunIPv6Route = "::/0";

  final List<String> gateway;
  final List<String> dns;
  final List<String> autoSystemRoutingTable;
  final String? autoOutboundsInterface;

  const XrayTunRouteConfig({
    this.gateway = const [],
    this.dns = const [],
    this.autoSystemRoutingTable = const [],
    this.autoOutboundsInterface,
  });

  factory XrayTunRouteConfig.fromTunSetting(TunSettingState state) {
    if (!AppPlatform.isWindows && !AppPlatform.isLinux) {
      return const XrayTunRouteConfig();
    }

    final gateway = <String>[tunIPv4Gateway];
    final dns = <String>[if (state.tunDnsIPv4.isNotEmpty) state.tunDnsIPv4];
    final autoSystemRoutingTable = <String>[tunIPv4Route];

    if (state.enableIPv6) {
      gateway.add(tunIPv6Gateway);
      if (state.tunDnsIPv6.isNotEmpty) {
        dns.add(state.tunDnsIPv6);
      }
      autoSystemRoutingTable.add(tunIPv6Route);
    }

    return XrayTunRouteConfig(
      gateway: gateway,
      dns: dns,
      autoSystemRoutingTable: autoSystemRoutingTable,
      autoOutboundsInterface: state.autoOutboundsInterface,
    );
  }

  void applyToXrayInboundTun(XrayInboundTun settings) {
    settings.gateway = gateway.isEmpty ? null : gateway;
    settings.dns = dns.isEmpty ? null : dns;
    settings.autoSystemRoutingTable = autoSystemRoutingTable.isEmpty
        ? null
        : autoSystemRoutingTable;
    settings.autoOutboundsInterface = autoOutboundsInterface;
  }

  void applyToRawTunSettings(Map<String, dynamic> settings) {
    removeFromRawTunSettings(settings);
    if (gateway.isNotEmpty) {
      settings[_gatewayKey] = gateway;
    }
    if (dns.isNotEmpty) {
      settings[_dnsKey] = dns;
    }
    if (autoSystemRoutingTable.isNotEmpty) {
      settings[_autoSystemRoutingTableKey] = autoSystemRoutingTable;
    }
    if (autoOutboundsInterface != null && autoOutboundsInterface!.isNotEmpty) {
      settings[_autoOutboundsInterfaceKey] = autoOutboundsInterface;
    }
  }

  static void removeFromRawTunSettings(Map<dynamic, dynamic> settings) {
    settings.remove(_gatewayKey);
    settings.remove(_dnsKey);
    settings.remove(_autoSystemRoutingTableKey);
    settings.remove(_autoOutboundsInterfaceKey);
  }
}
