/// A process resource, not VPN state. `exited` is false when cancelled.
class DesktopCoreExitWatch {
  final Future<bool> exited;
  final void Function() cancel;

  const DesktopCoreExitWatch(this.exited, this.cancel);
}
