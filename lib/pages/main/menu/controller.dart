import 'package:window_manager/window_manager.dart';

class MenuPageController {
  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }
}
