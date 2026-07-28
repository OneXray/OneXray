import 'package:onexray/core/desktop_startup/adapter.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/pigeon/messages.g.dart';

final class MacOSLaunchAtLoginAdapter extends LaunchAtLoginAdapter {
  final BridgeHostApi _api;

  MacOSLaunchAtLoginAdapter({BridgeHostApi? api})
    : _api = api ?? BridgeHostApi();

  @override
  Future<LaunchAtLoginStatus> query() async {
    return _map(await _api.queryLaunchAtLogin());
  }

  @override
  Future<LaunchAtLoginStatus> setEnabled(bool enabled) async {
    return _map(await _api.setLaunchAtLogin(enabled));
  }

  @override
  Future<bool> openSettings() {
    return _api.openLaunchAtLoginSettings();
  }

  static LaunchAtLoginStatus _map(NativeLaunchAtLoginResult result) {
    final state = switch (result.state) {
      NativeLaunchAtLoginState.enabled => LaunchAtLoginState.enabled,
      NativeLaunchAtLoginState.disabled => LaunchAtLoginState.disabled,
      NativeLaunchAtLoginState.requiresApproval =>
        LaunchAtLoginState.requiresApproval,
      NativeLaunchAtLoginState.unavailable => LaunchAtLoginState.unavailable,
      NativeLaunchAtLoginState.error => LaunchAtLoginState.error,
    };
    return LaunchAtLoginStatus(state, message: result.message);
  }
}
