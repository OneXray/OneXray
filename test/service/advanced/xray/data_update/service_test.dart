import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/service/advanced/xray/data_update/service.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

final class _UpdatePreferences extends InMemorySharedPreferencesAsync {
  _UpdatePreferences() : super.empty();

  Future<void> Function()? beforeRead;

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    if (key.endsWith('autoUpdate')) await beforeRead?.call();
    return super.getString(key, options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final preferences = _UpdatePreferences();
  SharedPreferencesAsyncPlatform.instance = preferences;
  late AppEventBus eventBus;
  final service = DataUpdateService();

  setUp(() async {
    preferences.beforeRead = null;
    await PreferencesKey().saveAutoUpdate({
      'subscriptionEnabled': false,
      'geoDataEnabled': true,
    });
    eventBus = AppEventBus();
    addTearDown(eventBus.close);
  });

  test(
    'disconnected automatic Geodata checks stop before reading files',
    () async {
      var connectionChecks = 0;
      await service.checkAndRun(
        isVpnConnected: () {
          connectionChecks++;
          return false;
        },
      );

      expect(connectionChecks, 1);
      expect(eventBus.state.downloading, isFalse);
    },
  );

  test(
    'connection is checked after awaiting automatic update preferences',
    () async {
      final reading = Completer<void>();
      final release = Completer<void>();
      preferences.beforeRead = () {
        reading.complete();
        return release.future;
      };
      var connected = true;
      final checkedStates = <bool>[];
      final update = service.checkAndRun(
        isVpnConnected: () {
          checkedStates.add(connected);
          return connected;
        },
      );
      await reading.future;
      connected = false;
      release.complete();
      await update;

      expect(checkedStates, [false]);
      expect(eventBus.state.downloading, isFalse);
    },
  );
}
