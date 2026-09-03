import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/auto_update/state.dart';

class AutoUpdatePageState {
  final AutoUpdateState autoUpdateState;
  final DownloadUserAgentMode userAgent;
  final bool loading;
  final bool loaded;
  final bool saving;
  final bool failed;
  AutoUpdatePageState({
    AutoUpdateState? autoUpdateState,
    this.userAgent = DownloadUserAgentMode.oneXray,
    this.loading = true,
    this.saving = false,
    this.failed = false,
    this.loaded = false,
  }) : autoUpdateState = autoUpdateState ?? AutoUpdateState();

  AutoUpdatePageState copyWith({
    DownloadUserAgentMode? userAgent,
    bool? loading,
    bool? loaded,
    bool? saving,
    bool? failed,
  }) => AutoUpdatePageState(
    autoUpdateState: autoUpdateState,
    userAgent: userAgent ?? this.userAgent,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    failed: failed ?? this.failed,
    loaded: loaded ?? this.loaded,
  );
}

class AutoUpdateController extends PageCubit<AutoUpdatePageState> {
  AutoUpdateController() : super(AutoUpdatePageState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(loading: true, failed: false));
    try {
      final value = AutoUpdateState();
      await value.readFromPreferences();
      final mode = await PreferencesKey().readDownloadUserAgentMode();
      emit(
        AutoUpdatePageState(
          autoUpdateState: value,
          userAgent: mode,
          loading: false,
          loaded: true,
        ),
      );
    } catch (_) {
      emit(state.copyWith(loading: false, failed: true));
    }
  }

  void updateSubscriptionEnabled(bool value) {
    state.autoUpdateState.subscriptionEnabled = value;
    emit(state.copyWith());
  }

  void updateSubscriptionInterval(AutoUpdateInterval? value) {
    if (value == null) return;
    state.autoUpdateState.subscriptionInterval = value;
    emit(state.copyWith());
  }

  void updateGeoDataEnable(bool value) {
    state.autoUpdateState.geoDataEnable = value;
    emit(state.copyWith());
  }

  void updateGeoDataInterval(AutoUpdateInterval? value) {
    if (value == null) return;
    state.autoUpdateState.geoDataInterval = value;
    emit(state.copyWith());
  }

  void updateUserAgent(DownloadUserAgentMode? value) {
    if (value != null) emit(state.copyWith(userAgent: value));
  }

  void cancel(BuildContext context) => context.pop();

  Future<void> save(BuildContext context) async {
    if (!state.loaded || state.saving) return;
    emit(state.copyWith(saving: true, failed: false));
    try {
      await state.autoUpdateState.saveToPreferences();
      await PreferencesKey().saveDownloadUserAgentMode(state.userAgent);
      await NetClient().updateUserAgentMode(state.userAgent);
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.prototypeSettingsSaved,
        );
        if (ModalRoute.of(context)?.isCurrent == true) context.pop();
      }
    } catch (_) {
      emit(state.copyWith(failed: true));
    } finally {
      emit(state.copyWith(saving: false));
    }
  }
}
