import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/windows/tun2socks.dart';

void main() {
  test('builds the credential-free VCore config with IPv6 policy', () {
    final enabled = buildWindowsTun2SocksConfig('1080', enableIPv6: true);
    expect(enabled, '''ipv6: true

tun:
  enable: true
  mtu: 1500

proxies:
  - name: onexray-local-socks
    type: socks5
    server: 127.0.0.1
    port: 1080
    udp: true

dns:
  enable: false

rules:
  - MATCH,onexray-local-socks
''');
    expect(
      buildWindowsTun2SocksConfig('1080', enableIPv6: false),
      enabled.replaceFirst('ipv6: true', 'ipv6: false'),
    );
    expect(
      () => buildWindowsTun2SocksConfig('0', enableIPv6: true),
      throwsA(isA<FormatException>()),
    );
  });
}
