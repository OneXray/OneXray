import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/windows/tun2socks.dart';

void main() {
  test('builds the fixed credential-free VCore config', () {
    expect(buildWindowsTun2SocksConfig('1080'), '''tun:
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
      () => buildWindowsTun2SocksConfig('0'),
      throwsA(isA<FormatException>()),
    );
  });
}
