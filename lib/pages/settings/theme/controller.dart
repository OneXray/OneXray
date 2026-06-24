import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';

class ThemeState {
  final ThemeCode themeCode;

  const ThemeState({this.themeCode = ThemeCode.system});

  ThemeState copyWith({ThemeCode? themeCode}) {
    return ThemeState(themeCode: themeCode ?? this.themeCode);
  }
}

class ThemeController extends Cubit<ThemeState> {
  ThemeController() : super(const ThemeState()) {
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
