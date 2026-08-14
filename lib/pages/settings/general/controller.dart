import 'dart:async';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';

class GeneralSettingsPageState {
  final bool connectOnAppLaunch;
  final DownloadUserAgentMode userAgentMode;
  final String userAgent;
  final bool loading;
  final bool updatingUserAgentMode;

  const GeneralSettingsPageState({
    this.connectOnAppLaunch = false,
    this.userAgentMode = DownloadUserAgentMode.defaultMode,
    this.userAgent = '',
    this.loading = true,
    this.updatingUserAgentMode = false,
  });

  GeneralSettingsPageState copyWith({
    bool? connectOnAppLaunch,
    DownloadUserAgentMode? userAgentMode,
    String? userAgent,
    bool? loading,
    bool? updatingUserAgentMode,
  }) {
    return GeneralSettingsPageState(
      connectOnAppLaunch: connectOnAppLaunch ?? this.connectOnAppLaunch,
      userAgentMode: userAgentMode ?? this.userAgentMode,
      userAgent: userAgent ?? this.userAgent,
      loading: loading ?? this.loading,
      updatingUserAgentMode:
          updatingUserAgentMode ?? this.updatingUserAgentMode,
    );
  }
}

class GeneralSettingsController extends PageCubit<GeneralSettingsPageState> {
  GeneralSettingsController() : super(const GeneralSettingsPageState()) {
    unawaited(_readSettings());
  }

  Future<void> _readSettings() async {
    final preferences = PreferencesKey();
    final connectOnAppLaunch = await preferences.readConnectOnAppLaunch();
    final userAgentMode = await preferences.readDownloadUserAgentMode();
    final netClient = NetClient();
    await netClient.asyncInit();
    if (isPageActive) {
      emit(
        state.copyWith(
          connectOnAppLaunch: connectOnAppLaunch,
          userAgentMode: userAgentMode,
          userAgent: netClient.downloadUserAgent,
          loading: false,
        ),
      );
    }
  }

  Future<void> updateConnectOnAppLaunch(bool enabled) async {
    await PreferencesKey().saveConnectOnAppLaunch(enabled);
    if (isPageActive) {
      emit(state.copyWith(connectOnAppLaunch: enabled));
    }
  }

  Future<void> updateUserAgentMode(DownloadUserAgentMode mode) async {
    if (state.loading || state.updatingUserAgentMode) {
      return;
    }
    if (mode == state.userAgentMode) {
      return;
    }
    emit(state.copyWith(updatingUserAgentMode: true));
    try {
      await PreferencesKey().saveDownloadUserAgentMode(mode);
      final netClient = NetClient();
      await netClient.updateUserAgentMode(mode);
      if (isPageActive) {
        emit(
          state.copyWith(
            userAgentMode: mode,
            userAgent: netClient.downloadUserAgent,
            updatingUserAgentMode: false,
          ),
        );
      }
    } finally {
      if (isPageActive && state.updatingUserAgentMode) {
        emit(state.copyWith(updatingUserAgentMode: false));
      }
    }
  }
}
