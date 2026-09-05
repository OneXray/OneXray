import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test(
    'automatic updates persist only global switches and intervals',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      const settings = {
        'subscriptionEnabled': false,
        'subscriptionInterval': 24,
        'geoDataEnabled': true,
        'geoDataInterval': 168,
      };
      final preferences = PreferencesKey();
      await preferences.saveAutoUpdate(settings);
      final state = AutoUpdateState();
      await state.readFromPreferences();
      await state.saveToPreferences();
      expect(await preferences.readAutoUpdate(), settings);
    },
  );

  test(
    'new product ignores legacy preferences without clearing platform state',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final storage = SharedPreferencesAsync();
      await storage.setBool('privacyAccepted04', true);
      await storage.setBool('firstRun03', false);
      await storage.setBool('connectOnAppLaunch', true);
      await storage.setInt('runningConfigId', 42);
      final preferences = PreferencesKey();
      expect(await preferences.readPrivacyAccepted(), isFalse);
      expect(await preferences.readFirstRun(), isTrue);
      expect(await preferences.readConnectOnAppLaunch(), isFalse);
      expect(await storage.getInt('runningConfigId'), 42);
      await preferences.savePrivacyAccepted(true);
      expect(await preferences.readPrivacyAccepted(), isTrue);
      expect(await storage.getBool('privacyAccepted04'), isTrue);
    },
  );
}
