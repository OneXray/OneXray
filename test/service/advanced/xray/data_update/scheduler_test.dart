import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/advanced/xray/data_update/scheduler.dart';
import 'package:onexray/service/advanced/xray/data_update/service.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
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

final class _RecordingUpdates implements DataUpdateService {
  final checks =
      <({bool subscriptions, bool geodata, bool Function() isVpnConnected})>[];

  @override
  Future<void> checkAndRun({
    required bool Function() isVpnConnected,
    bool updateSubscription = true,
    bool updateGeoData = true,
  }) async {
    checks.add((
      subscriptions: updateSubscription,
      geodata: updateGeoData,
      isVpnConnected: isVpnConnected,
    ));
  }

  @override
  Future<void> pauseForDataClear() async {}

  @override
  void resumeAfterDataClear() {}
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

  testWidgets('disconnected startup, resume and hourly checks skip Geodata', (
    tester,
  ) async {
    final updates = _RecordingUpdates();
    final service = BackgroundTaskService.forTesting(updates);
    try {
      service.init();
      await tester.pump();
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(hours: 1));

      expect(updates.checks, hasLength(3));
      for (final check in updates.checks) {
        expect(check.subscriptions, isTrue);
        expect(check.geodata, isFalse);
        expect(check.isVpnConnected(), isFalse);
      }
    } finally {
      service.dispose();
    }
  });

  testWidgets('connected checks wait three seconds and keep a live status', (
    tester,
  ) async {
    final updates = _RecordingUpdates();
    final service = BackgroundTaskService.forTesting(updates);
    try {
      service.init();
      await tester.pump();
      await AppFlutterApi().vpnStatusChanged(VpnStatus.connected);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(updates.checks, hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      expect(updates.checks, hasLength(2));
      final connectedCheck = updates.checks.last;
      expect(connectedCheck.geodata, isTrue);
      expect(connectedCheck.isVpnConnected(), isTrue);

      // Waiting for subscription updates must not retain a connected snapshot.
      await AppFlutterApi().vpnStatusChanged(VpnStatus.disconnected);
      await tester.pump();
      expect(connectedCheck.isVpnConnected(), isFalse);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(updates.checks.last.geodata, isFalse);
    } finally {
      service.dispose();
    }
  });

  testWidgets('disconnect and dispose cancel the delayed connected check', (
    tester,
  ) async {
    final updates = _RecordingUpdates();
    final service = BackgroundTaskService.forTesting(updates);
    try {
      service.init();
      await tester.pump();
      await AppFlutterApi().vpnStatusChanged(VpnStatus.connected);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await AppFlutterApi().vpnStatusChanged(VpnStatus.disconnected);
      await AppFlutterApi().vpnStatusChanged(VpnStatus.connected);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(updates.checks, hasLength(1));
      await tester.pump(const Duration(seconds: 2));
      expect(updates.checks, hasLength(2));
      expect(updates.checks.last.geodata, isTrue);

      await AppFlutterApi().vpnStatusChanged(VpnStatus.disconnected);
      await AppFlutterApi().vpnStatusChanged(VpnStatus.connected);
      await tester.pump();
      service.dispose();
      await tester.pump(const Duration(seconds: 3));
      expect(updates.checks, hasLength(2));
    } finally {
      service.dispose();
    }
  });

  testWidgets('startup reuses an already confirmed native connection', (
    tester,
  ) async {
    final updates = _RecordingUpdates();
    final service = BackgroundTaskService.forTesting(updates);
    try {
      service.init(vpnConnected: true);
      await tester.pump();
      expect(updates.checks.single.geodata, isTrue);
      expect(updates.checks.single.isVpnConnected(), isTrue);

      await AppFlutterApi().vpnStatusChanged(VpnStatus.connected);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(updates.checks, hasLength(1));
    } finally {
      service.dispose();
    }
  });
}
