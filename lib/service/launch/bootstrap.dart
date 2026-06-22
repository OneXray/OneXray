import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/service/event_bus/service.dart';

enum LaunchDestination { privacy, firstRun, home }

class LaunchBootstrapService {
  Future<LaunchDestination> resolveDestination() async {
    await _initTheme();
    final privacyAccepted = await PreferencesKey().readPrivacyAccepted();
    if (!privacyAccepted) {
      return LaunchDestination.privacy;
    }
    return resolveAcceptedDestination();
  }

  Future<LaunchDestination> resolveAcceptedDestination() async {
    await _initState();
    final firstRun = await PreferencesKey().readFirstRun();
    if (firstRun) {
      return LaunchDestination.firstRun;
    }
    return LaunchDestination.home;
  }

  Future<void> _initTheme() async {
    await AppEventBus.instance.asyncInitTheme();
  }

  Future<void> _initState() async {
    await AppEventBus.instance.asyncInitState();
  }
}
