import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:window_manager/window_manager.dart';

class ToolboxState {
  final bool hideDockIcon;

  const ToolboxState({this.hideDockIcon = false});

  ToolboxState copyWith({bool? hideDockIcon}) {
    return ToolboxState(hideDockIcon: hideDockIcon ?? this.hideDockIcon);
  }
}

class ToolboxController extends Cubit<ToolboxState> {
  ToolboxController() : super(const ToolboxState()) {
    _readData();
  }

  Future<void> _readData() async {
    final hideDockIcon = await PreferencesKey().readHideDockIcon();
    emit(state.copyWith(hideDockIcon: hideDockIcon));
  }

  Future<void> updateHideDockIcon(bool value) async {
    emit(state.copyWith(hideDockIcon: value));
    await PreferencesKey().saveHideDockIcon(value);
    await windowManager.setSkipTaskbar(state.hideDockIcon);
  }
}
