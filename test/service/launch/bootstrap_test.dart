import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/pages/launch/route.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/launch/bootstrap.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:onexray/service/shared/event_bus/enum.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = _Preferences();
  setUpAll(() => SharedPreferencesAsyncPlatform.instance = storage);
  setUp(() async {
    await SharedPreferencesAsync().clear();
    storage.boolReads.clear();
    final bus = AppEventBus();
    addTearDown(bus.close);
  });

  for (final scenario in [
    (
      privacy: false,
      firstRun: true,
      destination: LaunchDestination.setup,
      step: SetupStep.welcome,
    ),
    (
      privacy: true,
      firstRun: true,
      destination: LaunchDestination.setup,
      step: SetupStep.configuration,
    ),
    (
      privacy: true,
      firstRun: false,
      destination: LaunchDestination.connect,
      step: SetupStep.complete,
    ),
  ]) {
    test(
      'startup resolves ${scenario.step.name} without changing flags',
      () async {
        final preferences = PreferencesKey();
        await preferences.savePrivacyAccepted(scenario.privacy);
        await preferences.saveFirstRun(scenario.firstRun);
        await preferences.saveThemeCode('dark');
        await preferences.saveLanguageCode('en');

        final destination = await LaunchBootstrapService().resolveDestination();

        expect(destination, scenario.destination);
        expect(
          destination.route,
          scenario.destination == LaunchDestination.setup
              ? RouterPath.setup
              : RouterPath.connect,
        );
        expect(storage.boolReads, [
          'app2.privacyAccepted',
          if (scenario.privacy) 'app2.firstRun',
        ]);
        expect(AppEventBus.instance.state.themeCode, ThemeCode.dark);
        expect(AppEventBus.instance.state.languageCode, LanguageCode.en);
        expect(await SetupService().currentStep(), scenario.step);
        expect(await preferences.readPrivacyAccepted(), scenario.privacy);
        expect(await preferences.readFirstRun(), scenario.firstRun);
      },
    );
  }
}

final class _Preferences extends InMemorySharedPreferencesAsync {
  _Preferences() : super.empty();

  final boolReads = <String>[];

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) {
    boolReads.add(key);
    return super.getBool(key, options);
  }
}
