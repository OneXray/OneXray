import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/constants.dart';

Map<String, dynamic> createTunInboundMap() => XrayInbound(
  listen: NetConstants.proxyHost,
  protocol: 'tun',
  settings: XrayInboundTunSettings(
    name: 'OneXrayTun',
    mtu: VpnConstants.tunMtu,
  ).toJson(),
  tag: 'tunIn',
  sniffing: _createSniffing(),
).toJson();

Map<String, dynamic> createSocksInboundMap(String port) => XrayInbound(
  listen: NetConstants.proxyHost,
  port: port,
  protocol: 'socks',
  settings: XrayInboundSocksSettings(auth: 'noauth', udp: true).toJson(),
  tag: 'tunIn',
  sniffing: _createSniffing(),
).toJson();

XrayInboundSniffing _createSniffing() => XrayInboundSniffing(
  enabled: true,
  routeOnly: false,
  destOverride: ['http', 'tls', 'quic'],
);
