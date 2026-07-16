import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';

class ThemePageState {
  final ThemeCode themeCode;

  const ThemePageState({this.themeCode = ThemeCode.system});

  ThemePageState copyWith({ThemeCode? themeCode}) {
    return ThemePageState(themeCode: themeCode ?? this.themeCode);
  }
}

class ThemeController extends PageCubit<ThemePageState> {
  ThemeController() : super(const ThemePageState()) {
    _readData();
  }

  Future<void> _readData() async {
    final eventBus = AppEventBus.instance;
    emit(state.copyWith(themeCode: eventBus.state.themeCode));
  }

  void updateThemeCode(ThemeCode? value) {
    if (value != null) {
      emit(state.copyWith(themeCode: value));
    }
  }

  Future<void> save(BuildContext context) async {
    final eventBus = AppEventBus.instance;
    await eventBus.updateThemeCode(state.themeCode);
    if (context.mounted) {
      context.pop();
    }
  }
}
