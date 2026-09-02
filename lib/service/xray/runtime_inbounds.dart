import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';

Map<String, dynamic> createTunInboundMap() => <String, dynamic>{
  'listen': NetConstants.proxyHost,
  'protocol': 'tun',
  'settings': <String, dynamic>{
    'name': 'OneXrayTun',
    'mtu': VpnConstants.tunMtu,
  },
  'tag': 'tunIn',
  'sniffing': _createSniffingMap(),
};

Map<String, dynamic> createSocksInboundMap(String port) => <String, dynamic>{
  'listen': NetConstants.proxyHost,
  'port': port,
  'protocol': 'socks',
  'settings': <String, dynamic>{'auth': 'noauth', 'udp': true},
  'tag': 'tunIn',
  'sniffing': _createSniffingMap(),
};

Map<String, dynamic> _createSniffingMap() => <String, dynamic>{
  'enabled': true,
  'routeOnly': false,
  'destOverride': <String>['http', 'tls', 'quic'],
};

Map<String, dynamic> createPingInboundMap({
  String port = VpnConstants.randomPort,
  XrayInboundAccount? auth,
}) {
  return <String, dynamic>{
    'listen': NetConstants.proxyHost,
    'port': port,
    'protocol': 'http',
    if (auth?.isValid == true)
      'settings': <String, dynamic>{
        'allowTransparent': false,
        'users': <dynamic>[
          <String, dynamic>{'user': auth!.user, 'pass': auth.pass},
        ],
      },
    'tag': 'pingIn',
  };
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
