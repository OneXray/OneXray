enum LaunchAtLoginState {
  enabled,
  disabled,
  requiresApproval,
  unavailable,
  error,
}

final class LaunchAtLoginStatus {
  final LaunchAtLoginState state;
  final String? message;

  const LaunchAtLoginStatus(this.state, {this.message});

  const LaunchAtLoginStatus.enabled()
    : state = LaunchAtLoginState.enabled,
      message = null;

  const LaunchAtLoginStatus.disabled({this.message})
    : state = LaunchAtLoginState.disabled;

  const LaunchAtLoginStatus.unavailable({this.message})
    : state = LaunchAtLoginState.unavailable;

  const LaunchAtLoginStatus.error(String error)
    : state = LaunchAtLoginState.error,
      message = error;

  bool get enabled => state == LaunchAtLoginState.enabled;

  bool get registered =>
      state == LaunchAtLoginState.enabled ||
      state == LaunchAtLoginState.requiresApproval;
}
