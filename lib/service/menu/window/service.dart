import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:window_manager/window_manager.dart';

final class WindowService with WindowListener {
  static final WindowService _singleton = WindowService._internal();

  factory WindowService() => _singleton;

  WindowService._internal();

  //==========================
  var _initialized = false;

  Future<void> asyncInit() async {
    if (!AppPlatform.isDesktop || _initialized) {
      return;
    }
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    _initialized = true;

    final hideDockIcon = await PreferencesKey().readHideDockIcon();
    await windowManager.setSkipTaskbar(hideDockIcon);
  }

  void dispose() {
    if (!AppPlatform.isDesktop || !_initialized) {
      return;
    }
    windowManager.removeListener(this);
    _initialized = false;
  }

  @override
  Future<void> onWindowClose() async {
    super.onWindowClose();
    await windowManager.hide();
  }
}
