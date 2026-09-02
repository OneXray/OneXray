import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/xray/runtime_inbounds.dart';

void main() {
  test('XrayPorts allocates separate SOCKS, ping, and metrics ports', () async {
    var calls = 0;
    final ports = await XrayPorts.getPorts(
      excludedPorts: const <int>{10000},
      portProvider: (count) async {
        expect(count, 3);
        calls += 1;
        return calls == 1
            ? <int>[10000, 10001, 10002]
            : <int>[11000, 11001, 11002];
      },
    );

    expect(calls, 2);
    expect(ports?.socksPort, '11000');
    expect(ports?.pingPort, '11001');
    expect(ports?.metricsPort, '11002');
  });
}
