import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';

class LanguagePageState {
  final LanguageCode languageCode;
  final bool saving;

  const LanguagePageState({
    this.languageCode = LanguageCode.system,
    this.saving = false,
  });

  LanguagePageState copyWith({LanguageCode? languageCode, bool? saving}) {
    return LanguagePageState(
      languageCode: languageCode ?? this.languageCode,
      saving: saving ?? this.saving,
    );
  }
}

class LanguageController extends PageCubit<LanguagePageState> {
  LanguageController() : super(const LanguagePageState()) {
    _readData();
  }

  Future<void> _readData() async {
    final eventBus = AppEventBus.instance;
    emit(state.copyWith(languageCode: eventBus.state.languageCode));
  }

  void updateLanguageCode(LanguageCode? value) {
    if (value != null && !state.saving) {
      emit(state.copyWith(languageCode: value));
    }
  }

  Future<void> save(BuildContext context) async {
    if (state.saving) return;
    emit(state.copyWith(saving: true));
    try {
      await AppEventBus.instance.updateLanguageCode(state.languageCode);
      if (context.mounted) context.pop();
    } catch (_) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.buttonSaveFailed,
        );
      }
    } finally {
      emit(state.copyWith(saving: false));
    }
  }

  void cancel(BuildContext context) {
    if (!state.saving) context.pop();
  }
}
