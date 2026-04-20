import 'dart:io';

class AppPlatform {
  static bool get isIOS => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
  static bool get isMobile => Platform.isIOS || Platform.isAndroid;
  static bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
