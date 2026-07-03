import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:window_manager/window_manager.dart';

class ToolboxPageState {
  final bool hideDockIcon;

  const ToolboxPageState({this.hideDockIcon = false});

  ToolboxPageState copyWith({bool? hideDockIcon}) {
    return ToolboxPageState(hideDockIcon: hideDockIcon ?? this.hideDockIcon);
  }
}

class ToolboxController extends Cubit<ToolboxPageState> {
  ToolboxController() : super(const ToolboxPageState()) {
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
