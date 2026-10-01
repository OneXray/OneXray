import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/service/launch/app_startup.dart';
import 'package:onexray/service/shared/event_bus/service.dart';

enum LaunchDestination { setup, connect }

class LaunchBootstrapService {
  Future<LaunchDestination> resolveDestination() async {
    await _initTheme();
    final privacyAccepted = await PreferencesKey().readPrivacyAccepted();
    if (!privacyAccepted || await PreferencesKey().readFirstRun()) {
      final appStartup = AppStartupService();
      appStartup.suppressConnectOnAppLaunch();
      await appStartup.showMainWindow();
      return LaunchDestination.setup;
    }
    return LaunchDestination.connect;
  }

  Future<void> _initTheme() async {
    await AppEventBus.instance.asyncInitTheme();
  }
}
