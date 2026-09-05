import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/background_task/service.dart';
import 'package:onexray/service/event_bus/service.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

final class _CountingPreferences extends InMemorySharedPreferencesAsync {
  _CountingPreferences() : super.empty();
  int updateReads = 0;

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) {
    if (key.endsWith('autoUpdate')) updateReads++;
    return super.getString(key, options);
  }
}

void main() {
  testWidgets('only new connected edges retry; resume and hourly checks remain', (
    tester,
  ) async {
    final preferences = _CountingPreferences();
    SharedPreferencesAsyncPlatform.instance = preferences;
    // Observe real scheduling without allowing network tasks or database reads.
    await PreferencesKey().saveAutoUpdate({
      'subscriptionEnabled': false,
      'geoDataEnabled': false,
    });
    final eventBus = AppEventBus();
    final service = BackgroundTaskService();
    addTearDown(() async {
      service.dispose();
      await eventBus.close();
    });
    service.init();
    await tester.pump();
    expect(preferences.updateReads, 1);

    for (var index = 0; index < 3; index++) {
      await AppFlutterApi().vpnStatusChanged(VpnStatus.connected);
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(preferences.updateReads, 2);
    await AppFlutterApi().vpnStatusChanged(VpnStatus.connected);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(preferences.updateReads, 2);

    await AppFlutterApi().vpnStatusChanged(VpnStatus.disconnected);
    await AppFlutterApi().vpnStatusChanged(VpnStatus.connected);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(preferences.updateReads, 3);

    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(preferences.updateReads, 4);
    await tester.pump(const Duration(hours: 1));
    expect(preferences.updateReads, 5);
    // Widget tests verify pending timers before the outer test tear-down runs.
    service.dispose();
  });
}
