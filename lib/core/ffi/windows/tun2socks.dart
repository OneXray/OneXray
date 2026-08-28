String buildWindowsTun2SocksConfig(
  String socksPort, {
  required bool enableIPv6,
}) {
  final port = int.tryParse(socksPort);
  if (port == null || port < 1 || port > 65535) {
    throw const FormatException('invalid Windows SOCKS5 port');
  }
  return '''ipv6: $enableIPv6

tun:
  enable: true
  mtu: 1500

proxies:
  - name: onexray-local-socks
    type: socks5
    server: 127.0.0.1
    port: $port
    udp: true

dns:
  enable: false

rules:
  - MATCH,onexray-local-socks
''';
}
