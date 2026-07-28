import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/app_startup/service.dart';
import 'package:window_manager/window_manager.dart';

class DesktopSettingsPageState {
  final LaunchAtLoginStatus launchAtLogin;
  final bool startHidden;
  final bool hideDockIcon;
  final bool loading;
  final bool changingLaunchAtLogin;

  const DesktopSettingsPageState({
    this.launchAtLogin = const LaunchAtLoginStatus.unavailable(),
    this.startHidden = false,
    this.hideDockIcon = false,
    this.loading = true,
    this.changingLaunchAtLogin = false,
  });

  bool get launchToggleEnabled =>
      !loading &&
      !changingLaunchAtLogin &&
      launchAtLogin.state != LaunchAtLoginState.unavailable &&
      launchAtLogin.state != LaunchAtLoginState.error;

  bool get behaviorSettingsEnabled => !loading;

  bool get requiresApproval =>
      launchAtLogin.state == LaunchAtLoginState.requiresApproval;

  DesktopSettingsPageState copyWith({
    LaunchAtLoginStatus? launchAtLogin,
    bool? startHidden,
    bool? hideDockIcon,
    bool? loading,
    bool? changingLaunchAtLogin,
  }) {
    return DesktopSettingsPageState(
      launchAtLogin: launchAtLogin ?? this.launchAtLogin,
      startHidden: startHidden ?? this.startHidden,
      hideDockIcon: hideDockIcon ?? this.hideDockIcon,
      loading: loading ?? this.loading,
      changingLaunchAtLogin:
          changingLaunchAtLogin ?? this.changingLaunchAtLogin,
    );
  }
}

class DesktopSettingsController extends PageCubit<DesktopSettingsPageState>
    with WidgetsBindingObserver {
  DesktopSettingsController() : super(const DesktopSettingsPageState()) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_readSettings());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_readSettings());
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }

  Future<void> _readSettings() async {
    if (isPageActive) {
      emit(state.copyWith(loading: true));
    }
    try {
      final preferences = PreferencesKey();
      final launchAtLogin = await AppStartupService().queryLaunchAtLogin();
      final startHidden = await preferences.readDesktopStartHidden();
      final hideDockIcon = AppPlatform.isMacOS
          ? await preferences.readHideDockIcon()
          : false;
      if (!isPageActive) {
        return;
      }
      emit(
        state.copyWith(
          launchAtLogin: launchAtLogin,
          startHidden: startHidden,
          hideDockIcon: hideDockIcon,
          loading: false,
        ),
      );
    } catch (error, stackTrace) {
      ygLogger("read desktop startup settings failed: $error\n$stackTrace");
      if (isPageActive) {
        emit(
          state.copyWith(
            launchAtLogin: LaunchAtLoginStatus.error(error.toString()),
            loading: false,
          ),
        );
      }
    }
  }

  Future<void> updateLaunchAtLogin(BuildContext context, bool enabled) async {
    if (state.changingLaunchAtLogin) {
      return;
    }
    emit(state.copyWith(changingLaunchAtLogin: true));
    try {
      final result = await AppStartupService().setLaunchAtLogin(enabled);
      if (!isPageActive) {
        return;
      }
      emit(state.copyWith(launchAtLogin: result, changingLaunchAtLogin: false));
      if (result.state == LaunchAtLoginState.error ||
          result.state == LaunchAtLoginState.unavailable) {
        if (context.mounted) {
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.settingsPageLaunchAtLoginUpdateFailed,
          );
        }
        ygLogger(
          "update launch at login failed: "
          "${result.message ?? result.state.name}",
        );
      }
    } catch (error, stackTrace) {
      ygLogger("update launch at login failed: $error\n$stackTrace");
      if (isPageActive) {
        emit(state.copyWith(changingLaunchAtLogin: false));
      }
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.settingsPageLaunchAtLoginUpdateFailed,
        );
      }
    }
  }

  Future<void> updateStartHidden(bool enabled) async {
    await PreferencesKey().saveDesktopStartHidden(enabled);
    if (isPageActive) {
      emit(state.copyWith(startHidden: enabled));
    }
  }

  Future<void> updateHideDockIcon(bool enabled) async {
    await PreferencesKey().saveHideDockIcon(enabled);
    await windowManager.setSkipTaskbar(enabled);
    if (isPageActive) {
      emit(state.copyWith(hideDockIcon: enabled));
    }
  }

  Future<void> openSystemSettings(BuildContext context) async {
    final opened = await AppStartupService().openLaunchAtLoginSettings();
    if (!opened && context.mounted) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.settingsPageLaunchAtLoginUnavailable,
      );
    }
  }
}
