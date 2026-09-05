import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';

void main() {
  test(
    'unchanged native replies still broadcast without repeating logs',
    () async {
      final api = AppFlutterApi();
      await api.vpnStatusChanged(VpnStatus.disconnected);
      await api.refreshVpn(RefreshVpnResult.notInstalled);
      final messages = <String?>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) => messages.add(message);
      addTearDown(() => debugPrint = previousDebugPrint);
      final statuses = <VpnStatus>[];
      final statusSubscription = api.vpnStatusController.stream.listen(
        statuses.add,
      );
      addTearDown(statusSubscription.cancel);

      await api.vpnStatusChanged(VpnStatus.connected);
      await api.vpnStatusChanged(VpnStatus.connected);
      await api.vpnStatusChanged(VpnStatus.disconnected);
      await api.vpnStatusChanged(VpnStatus.disconnected);
      await api.refreshVpn(RefreshVpnResult.installed);
      await api.refreshVpn(RefreshVpnResult.installed);
      await Future<void>.delayed(Duration.zero);

      expect(statuses, [
        VpnStatus.connected,
        VpnStatus.connected,
        VpnStatus.disconnected,
        VpnStatus.disconnected,
      ]);
      expect(messages, [
        'vpnStatusChanged connected',
        'vpnStatusChanged disconnected',
        'refreshVpn installed',
      ]);
    },
  );
}
