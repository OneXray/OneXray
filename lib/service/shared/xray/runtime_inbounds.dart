import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/constants.dart';

XrayInbound createTunInbound({
  List<String>? gateway,
  List<String>? dns,
  List<String>? autoSystemRoutingTable,
  String? autoOutboundsInterface,
  bool fakeDns = false,
}) => XrayInbound(
  listen: NetConstants.proxyHost,
  protocol: 'tun',
  settings: XrayInboundTunSettings(
    name: 'OneXrayTun',
    mtu: VpnConstants.tunMtu,
    gateway: gateway,
    dns: dns,
    autoSystemRoutingTable: autoSystemRoutingTable,
    autoOutboundsInterface: autoOutboundsInterface,
  ).toJson(),
  tag: 'tunIn',
  sniffing: _createSniffing(fakeDns),
);

XrayInbound createSocksInbound(String port, {bool fakeDns = false}) =>
    XrayInbound(
      listen: NetConstants.proxyHost,
      port: port,
      protocol: 'socks',
      settings: XrayInboundSocksSettings(auth: 'noauth', udp: true).toJson(),
      tag: 'tunIn',
      sniffing: _createSniffing(fakeDns),
    );

XrayInboundSniffing _createSniffing(bool fakeDns) => XrayInboundSniffing(
  enabled: true,
  routeOnly: false,
  destOverride: ['http', 'tls', 'quic', if (fakeDns) 'fakedns'],
);
