import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

class MenuPageController extends Cubit<int> {
  MenuPageController() : super(0);

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }
}
