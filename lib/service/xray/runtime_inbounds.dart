import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';

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

Map<String, dynamic> createPingInboundMap({
  String port = VpnConstants.randomPort,
  XrayInboundAccount? auth,
}) {
  return XrayInbound(
    listen: NetConstants.proxyHost,
    port: port,
    protocol: 'http',
    settings: auth?.isValid == true
        ? XrayInboundHttpSettings(
            allowTransparent: false,
            users: [auth!],
          ).toJson()
        : null,
    tag: 'pingIn',
  ).toJson();
}

class XrayPorts {
  String socksPort;
  String pingPort;
  String metricsPort;
  final XrayInboundAccount pingAuth;

  XrayPorts(
    this.pingPort,
    this.metricsPort,
    this.pingAuth, {
    this.socksPort = "",
  });

  static Future<XrayPorts?> getPorts({
    Set<int> excludedPorts = const <int>{},
    Future<List<int>> Function(int)? portProvider,
  }) async {
    for (var i = 0; i < 5; i++) {
      final ports = await (portProvider ?? AppHostApi().getFreePorts)(3);
      final availablePorts = ports
          .where((port) => !excludedPorts.contains(port))
          .toSet()
          .toList();
      if (availablePorts.length == 3) {
        return XrayPorts(
          '${availablePorts[1]}',
          '${availablePorts[2]}',
          XrayInboundAccountFactory.random(),
          socksPort: '${availablePorts[0]}',
        );
      }
    }
    return null;
  }
}
