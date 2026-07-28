import 'package:onexray/core/desktop_startup/model.dart';

abstract class LaunchAtLoginAdapter {
  Future<LaunchAtLoginStatus> query();

  Future<LaunchAtLoginStatus> setEnabled(bool enabled);

  Future<bool> openSettings() async => false;
}
