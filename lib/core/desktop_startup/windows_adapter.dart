import 'dart:io';

import 'package:onexray/core/desktop_startup/adapter.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';

final class WindowsLaunchAtLoginAdapter extends LaunchAtLoginAdapter {
  final WindowsNativeApi _native;
  final bool _packageAvailable;

  WindowsLaunchAtLoginAdapter({
    WindowsNativeApi? native,
    bool? packageAvailable,
  }) : _native = native ?? WindowsNativeApi(),
       _packageAvailable =
           packageAvailable ?? AppHostApi().windowsPackageAvailable;

  @override
  Future<LaunchAtLoginStatus> query() async {
    if (!_packageAvailable) {
      return const LaunchAtLoginStatus.unavailable();
    }
    try {
      return _status(await _native.getStartupTaskStatus());
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  @override
  Future<LaunchAtLoginStatus> setEnabled(bool enabled) async {
    if (!_packageAvailable) {
      return const LaunchAtLoginStatus.unavailable();
    }
    try {
      return _status(await _native.setStartupTaskEnabled(enabled));
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  @override
  Future<bool> openSettings() async {
    if (!_packageAvailable) {
      return false;
    }
    try {
      return await Process.start('explorer.exe', const [
        'ms-settings:startupapps',
      ]).then((_) => true);
    } catch (_) {
      return false;
    }
  }

  static LaunchAtLoginStatus _status(WindowsStartupTaskState state) {
    return switch (state) {
      WindowsStartupTaskState.enabled => const LaunchAtLoginStatus.enabled(),
      WindowsStartupTaskState.disabled => const LaunchAtLoginStatus.disabled(),
      WindowsStartupTaskState.requiresApproval => const LaunchAtLoginStatus(
        LaunchAtLoginState.requiresApproval,
      ),
      WindowsStartupTaskState.unavailable =>
        const LaunchAtLoginStatus.unavailable(),
    };
  }
}
