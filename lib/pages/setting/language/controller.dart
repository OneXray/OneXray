import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';

class LanguageState {
  final LanguageCode languageCode;

  const LanguageState({this.languageCode = LanguageCode.system});

  LanguageState copyWith({LanguageCode? languageCode}) {
    return LanguageState(languageCode: languageCode ?? this.languageCode);
  }
}

class LanguageController extends Cubit<LanguageState> {
  LanguageController() : super(const LanguageState()) {
    _readData();
  }

  Future<void> _readData() async {
    final eventBus = AppEventBus.instance;
    emit(state.copyWith(languageCode: eventBus.state.languageCode));
  }

  void updateLanguageCode(LanguageCode? value) {
    if (value != null) {
      emit(state.copyWith(languageCode: value));
    }
  }

  Future<void> save(BuildContext context) async {
    final eventBus = AppEventBus.instance;
    await eventBus.updateLanguageCode(state.languageCode);
    if (context.mounted) {
      context.pop();
    }
  }
}
