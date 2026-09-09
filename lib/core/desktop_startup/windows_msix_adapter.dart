import 'dart:io';

import 'package:onexray/core/desktop_startup/adapter.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';

final class WindowsMsixLaunchAtLoginAdapter extends LaunchAtLoginAdapter {
  final WindowsNativeApi _native;

  WindowsMsixLaunchAtLoginAdapter({WindowsNativeApi? native})
    : _native = native ?? WindowsNativeApi();

  @override
  Future<LaunchAtLoginStatus> query() async {
    try {
      return _status(await _native.getStartupTaskStatus());
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  @override
  Future<LaunchAtLoginStatus> setEnabled(bool enabled) async {
    try {
      return _status(await _native.setStartupTaskEnabled(enabled));
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  @override
  Future<bool> openSettings() async {
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
