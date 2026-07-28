import 'package:onexray/core/desktop_startup/adapter.dart';
import 'package:onexray/core/desktop_startup/linux_adapter.dart';
import 'package:onexray/core/desktop_startup/macos_adapter.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/desktop_startup/windows_adapter.dart';
import 'package:onexray/core/tools/platform.dart';

final class DesktopStartupPlatform {
  static final DesktopStartupPlatform _singleton =
      DesktopStartupPlatform._internal();

  factory DesktopStartupPlatform() => _singleton;

  DesktopStartupPlatform._internal();

  late final LaunchAtLoginAdapter? _adapter = _createAdapter();

  Future<LaunchAtLoginStatus> queryLaunchAtLogin() async {
    final adapter = _adapter;
    if (adapter == null) {
      return const LaunchAtLoginStatus.unavailable();
    }
    return adapter.query();
  }

  Future<LaunchAtLoginStatus> setLaunchAtLogin(bool enabled) async {
    final adapter = _adapter;
    if (adapter == null) {
      return const LaunchAtLoginStatus.unavailable();
    }
    return adapter.setEnabled(enabled);
  }

  Future<bool> openLaunchAtLoginSettings() async {
    return await _adapter?.openSettings() ?? false;
  }

  static LaunchAtLoginAdapter? _createAdapter() {
    if (AppPlatform.isMacOS) {
      return MacOSLaunchAtLoginAdapter();
    }
    if (AppPlatform.isWindows) {
      return WindowsLaunchAtLoginAdapter();
    }
    if (AppPlatform.isLinux) {
      return LinuxLaunchAtLoginAdapter();
    }
    return null;
  }
}
