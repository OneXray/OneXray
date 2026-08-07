import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/vpn/service.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    eventBus = AppEventBus();
  });

  tearDown(() async {
    await eventBus.close();
  });

  test('TUN settings treat preparing and connecting as active', () {
    final vpnService = VpnService();

    eventBus.updateVpnActionState(VpnActionState.preparing);
    expect(vpnService.vpnRunningOrStarting, isTrue);

    eventBus.updateVpnActionState(VpnActionState.connecting);
    expect(vpnService.vpnRunningOrStarting, isTrue);

    eventBus.updateVpnActionState(VpnActionState.idle);
    expect(vpnService.vpnRunningOrStarting, isFalse);
  });
}
