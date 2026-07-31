import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/tun_settings/state.dart';

void main() {
  test('Apple network routing uses system-compatible defaults', () {
    final state = TunSettingsState();

    expect(state.includeAllNetworks, isFalse);
    expect(state.excludeLocalNetworks, isTrue);
    expect(state.excludeCellularServices, isTrue);
    expect(state.excludeAPNs, isTrue);
    expect(state.excludeDeviceCommunication, isTrue);

    final tun = state.tunJson;
    expect(tun.includeAllNetworks, isFalse);
    expect(tun.excludeLocalNetworks, isTrue);
    expect(tun.excludeCellularServices, isTrue);
    expect(tun.excludeAPNs, isTrue);
    expect(tun.excludeDeviceCommunication, isTrue);
  });

  test('Apple network routing values are written to TunJson', () {
    final state = TunSettingsState()
      ..includeAllNetworks = true
      ..excludeLocalNetworks = false
      ..excludeCellularServices = false
      ..excludeAPNs = false
      ..excludeDeviceCommunication = false;

    final tun = state.tunJson;
    expect(tun.includeAllNetworks, isTrue);
    expect(tun.excludeLocalNetworks, isFalse);
    expect(tun.excludeCellularServices, isFalse);
    expect(tun.excludeAPNs, isFalse);
    expect(tun.excludeDeviceCommunication, isFalse);
  });
}
