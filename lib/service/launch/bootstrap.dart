import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/service/app_startup/service.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/launch/storage_preparation.dart';

enum LaunchDestination { privacy, firstRun, connect }

class LaunchBootstrapService {
  Future<LaunchDestination> resolveDestination() async {
    await _initTheme();
    final privacyAccepted = await PreferencesKey().readPrivacyAccepted();
    if (!privacyAccepted) {
      final appStartup = AppStartupService();
      appStartup.suppressConnectOnAppLaunch();
      await appStartup.showMainWindow();
      return LaunchDestination.privacy;
    }
    return resolveAcceptedDestination();
  }

  Future<LaunchDestination> resolveAcceptedDestination() async {
    final firstRun = await PreferencesKey().readFirstRun();
    if (firstRun) {
      final appStartup = AppStartupService();
      appStartup.suppressConnectOnAppLaunch();
      await appStartup.showMainWindow();
      return LaunchDestination.firstRun;
    }
    await StoragePreparation.ensureReady();
    return LaunchDestination.connect;
  }

  Future<void> _initTheme() async {
    await AppEventBus.instance.asyncInitTheme();
  }
}
