import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/ping/state.dart';

class PingPageState {
  final PingState pingState;
  final bool loading;
  final bool loaded;
  final bool saving;
  final String? error;

  PingPageState({
    PingState? pingState,
    this.loading = true,
    this.loaded = false,
    this.saving = false,
    this.error,
  }) : pingState = pingState ?? PingState();

  PingPageState copyWith({
    bool? loading,
    bool? loaded,
    bool? saving,
    String? error,
  }) {
    return PingPageState(
      pingState: pingState,
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      saving: saving ?? this.saving,
      error: error,
    );
  }
}

class PingController extends PageCubit<PingPageState> {
  PingController() : super(PingPageState()) {
    load();
  }

  final customUrlController = TextEditingController();

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    try {
      final pingState = PingState();
      await pingState.readFromPreferences();
      if (!isPageActive) return;
      customUrlController.text = pingState.customUrl;
      emit(PingPageState(pingState: pingState, loading: false, loaded: true));
    } catch (_) {
      emit(state.copyWith(loading: false, error: 'unavailable'));
    }
  }

  @override
  void disposePageResources() {
    customUrlController.dispose();
  }

  void updateTimeout(double value) {
    state.pingState.timeout = value;
    emit(state.copyWith());
  }

  void updateUrl(String value) {
    final url = PingUrl.fromString(value);
    if (url != null) {
      state.pingState.url = url;
      emit(state.copyWith());
    }
  }

  void cancel(BuildContext context) => context.pop();

  Future<void> save(BuildContext context) async {
    if (!state.loaded || state.saving) return;
    final customUrl = customUrlController.text.trim();
    if (state.pingState.url == PingUrl.custom) {
      final localizations = AppLocalizations.of(context)!;
      if (customUrl.isEmpty) {
        ContextAlert.showToast(context, localizations.prototypeEnterHttpUrl);
        return;
      }
      if (!PingUrl.isValidCustomUrl(customUrl)) {
        ContextAlert.showToast(context, localizations.prototypeEnterHttpUrl);
        return;
      }
    }
    emit(state.copyWith(saving: true));
    try {
      state.pingState.customUrl = customUrl;
      await state.pingState.saveToPreferences();
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.prototypeSettingsSaved,
        );
        if (ModalRoute.of(context)?.isCurrent == true) context.pop();
      }
    } catch (_) {
      emit(state.copyWith(error: 'unavailable'));
    } finally {
      emit(state.copyWith(saving: false, error: state.error));
    }
  }
}
