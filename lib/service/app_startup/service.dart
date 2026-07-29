import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/desktop_startup/platform.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/geo_data/system_dat_service.dart';
import 'package:onexray/service/menu/tray/service.dart';
import 'package:onexray/service/menu/window/service.dart';
import 'package:onexray/service/vpn/service.dart';

final class AppStartupService {
  static final AppStartupService _singleton = AppStartupService._internal();

  factory AppStartupService() => _singleton;

  AppStartupService._internal();

  final _platform = DesktopStartupPlatform();
  var _startHidden = false;
  var _connectOnAppLaunch = false;
  var _connectOnAppLaunchSuppressed = false;
  var _windowReady = false;
  var _windowShouldBeVisible = true;
  var _appLaunchHandled = false;

  Future<void> prepare() async {
    final preferences = PreferencesKey();
    try {
      _connectOnAppLaunch = await preferences.readConnectOnAppLaunch();
    } catch (error, stackTrace) {
      ygLogger("read connect on app launch failed: $error\n$stackTrace");
      _connectOnAppLaunch = false;
    }

    if (!AppPlatform.isDesktop) {
      return;
    }
    try {
      _startHidden = await preferences.readDesktopStartHidden();
    } catch (error, stackTrace) {
      ygLogger("read desktop startup settings failed: $error\n$stackTrace");
      _startHidden = false;
    }

    _windowShouldBeVisible = !_startHidden;
  }

  Future<void> onWindowReady() async {
    if (!AppPlatform.isDesktop) {
      return;
    }
    _windowReady = true;
    if (_windowShouldBeVisible) {
      await WindowService().showAndFocus();
    } else {
      await WindowService().hide();
    }
  }

  Future<void> showMainWindow() async {
    if (!AppPlatform.isDesktop) {
      return;
    }
    _windowShouldBeVisible = true;
    if (_windowReady) {
      await WindowService().showAndFocus();
    }
  }

  void suppressConnectOnAppLaunch() {
    _connectOnAppLaunchSuppressed = true;
  }

  Future<void> handleServicesReady() async {
    if (_appLaunchHandled) {
      return;
    }
    _appLaunchHandled = true;

    if (AppPlatform.isDesktop) {
      try {
        await TrayService().refreshTrayManager();
      } catch (error, stackTrace) {
        ygLogger("initialize startup tray failed: $error\n$stackTrace");
        await showMainWindow();
        return;
      }
    }

    if (!_connectOnAppLaunch || _connectOnAppLaunchSuppressed) {
      return;
    }

    try {
      await SystemGeoDatService().checkAssets();
      final result = await VpnService().startDefaultVpn();
      if (result.state != NativeVpnCommandState.success) {
        ygLogger(
          "connect on app launch failed: "
          "${result.message ?? result.state.name}",
        );
        await showMainWindow();
      }
    } catch (error, stackTrace) {
      ygLogger("connect on app launch failed: $error\n$stackTrace");
      await showMainWindow();
    }
  }

  Future<LaunchAtLoginStatus> queryLaunchAtLogin() {
    return _platform.queryLaunchAtLogin();
  }

  Future<LaunchAtLoginStatus> setLaunchAtLogin(bool enabled) {
    return _platform.setLaunchAtLogin(enabled);
  }

  Future<bool> openLaunchAtLoginSettings() {
    return _platform.openLaunchAtLoginSettings();
  }

  Future<void> unregisterForDataCleanup() async {
    if (!AppPlatform.isDesktop) {
      return;
    }
    final result = await setLaunchAtLogin(false);
    if (result.state == LaunchAtLoginState.disabled) {
      return;
    }
    final message = result.message ?? result.state.name;
    ygLogger("disable launch at login during data cleanup failed: $message");
    throw StateError(
      "disable launch at login during data cleanup failed: $message",
    );
  }
}
