import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/settings/app_icon/controller.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/data_cleanup/service.dart';
import 'package:onexray/service/app_startup/service.dart';
import 'package:onexray/service/doc/helper.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PreferencesPageState {
  final String appVersion;
  final String xrayVersion;
  final AppIcon appIcon;
  final bool connectOnLaunch;
  final bool loading;
  final bool saving;
  final bool checkingUpdate;
  final bool clearingData;
  const PreferencesPageState({
    this.appVersion = '—',
    this.xrayVersion = '—',
    this.appIcon = AppIcon.primary,
    this.connectOnLaunch = false,
    this.loading = true,
    this.saving = false,
    this.checkingUpdate = false,
    this.clearingData = false,
  });

  PreferencesPageState copyWith({
    String? appVersion,
    String? xrayVersion,
    AppIcon? appIcon,
    bool? connectOnLaunch,
    bool? loading,
    bool? saving,
    bool? checkingUpdate,
    bool? clearingData,
  }) => PreferencesPageState(
    appVersion: appVersion ?? this.appVersion,
    xrayVersion: xrayVersion ?? this.xrayVersion,
    appIcon: appIcon ?? this.appIcon,
    connectOnLaunch: connectOnLaunch ?? this.connectOnLaunch,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    checkingUpdate: checkingUpdate ?? this.checkingUpdate,
    clearingData: clearingData ?? this.clearingData,
  );
}

enum PreferencesLink {
  documentation,
  review,
  community,
  feedback,
  source,
  credits,
  privacy,
}

class PreferencesController extends PageCubit<PreferencesPageState> {
  PreferencesController() : super(const PreferencesPageState()) {
    _readVersions();
    _readPreferences();
  }

  bool get showAppIcon => AppPlatform.isIOS || AppPlatform.isMacOS;

  Future<void> _readVersions() async {
    var appVersion = '—';
    var xrayVersion = '—';
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Optional display facts remain unavailable instead of using demo values.
    }
    try {
      final version = await AppHostApi().xrayVersion();
      if (version.isNotEmpty) xrayVersion = version;
    } catch (_) {
      // App metadata can still be shown when the native version call fails.
    }
    emit(state.copyWith(appVersion: appVersion, xrayVersion: xrayVersion));
  }

  Future<void> _readPreferences() async {
    try {
      final connect = await PreferencesKey().readConnectOnAppLaunch();
      final icon = showAppIcon
          ? AppIcon.fromString(await AppHostApi().getCurrentAppIcon())
          : null;
      emit(
        state.copyWith(
          connectOnLaunch: connect,
          appIcon: icon ?? AppIcon.primary,
          loading: false,
        ),
      );
    } catch (_) {
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> openSetting(
    BuildContext context,
    AppSecondaryDestination destination,
  ) async {
    await context.pushScoped(destination);
    if (isPageActive && destination == AppSecondaryDestination.appIcon) {
      await _readPreferences();
    }
  }

  Future<void> setConnectOnLaunch(BuildContext context, bool value) async {
    if (state.saving || state.loading) return;
    emit(state.copyWith(saving: true));
    try {
      await PreferencesKey().saveConnectOnAppLaunch(value);
      emit(state.copyWith(connectOnLaunch: value));
    } catch (_) {
      if (context.mounted) _showUnavailable(context);
    } finally {
      emit(state.copyWith(saving: false));
    }
  }

  Future<void> checkUpdate(BuildContext context) async {
    if (state.checkingUpdate) return;
    emit(state.copyWith(checkingUpdate: true));
    try {
      final result = await AppUpdateService().checkForUpdate();
      if (!context.mounted) return;
      switch (result.status) {
        case AppUpdateCheckStatus.available:
          final update = result.updateInfo!;
          AppEventBus.instance.updateAppUpdateInfo(update);
          await context.pushAppUpdateDialog(update);
        case AppUpdateCheckStatus.upToDate:
          AppEventBus.instance.updateAppUpdateInfo(null);
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.appUpdateAlreadyLatest,
          );
        case AppUpdateCheckStatus.failed:
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.appUpdateCheckFailed,
          );
      }
    } catch (_) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.appUpdateCheckFailed,
        );
      }
    } finally {
      emit(state.copyWith(checkingUpdate: false));
    }
  }

  Future<void> clearData(BuildContext context) async {
    if (state.clearingData) return;
    final l10n = AppLocalizations.of(context)!;
    emit(state.copyWith(clearingData: true));
    try {
      if (!await AppConfirmationDialog(
            title: l10n.prototypeClearAllDataQuestion,
            content: l10n.prototypeClearAllDataWarning,
            cancelLabel: l10n.prototypeCancel,
            confirmLabel: l10n.prototypeConfirmClearData,
            destructive: true,
            barrierDismissible: false,
          ).show(context) ||
          !context.mounted) {
        return;
      }
      if (await AppDataCleanupService().clearFromSettings()) {
        AppStartupService().suppressConnectOnAppLaunch();
        emit(state.copyWith(connectOnLaunch: false));
        if (context.mounted) {
          context.goPrimaryRoot(AppPrimaryDestination.connect);
        }
      } else if (context.mounted) {
        _showUnavailable(context);
      }
    } catch (_) {
      if (context.mounted) _showUnavailable(context);
    } finally {
      emit(state.copyWith(clearingData: false));
    }
  }

  Future<void> setTheme(BuildContext context, ThemeCode theme) async {
    try {
      await AppEventBus.instance.updateThemeCode(theme);
    } catch (_) {
      if (context.mounted) _showUnavailable(context);
    }
  }

  Future<void> openLink(BuildContext context, PreferencesLink link) async {
    final uri = switch (link) {
      PreferencesLink.documentation => DocURLHelper.docUri(),
      PreferencesLink.review => null,
      PreferencesLink.community => Uri.parse('https://t.me/OneXrayApp'),
      PreferencesLink.feedback => Uri.parse(
        'https://github.com/OneXray/OneXray/issues/new',
      ),
      PreferencesLink.source => Uri.parse('https://github.com/OneXray/OneXray'),
      PreferencesLink.credits => DocURLHelper.creditsUri(),
      PreferencesLink.privacy => DocURLHelper.privacyUri(),
    };
    try {
      if (uri == null) {
        final review = InAppReview.instance;
        if (await review.isAvailable()) await review.requestReview();
        return;
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) _showUnavailable(context);
      }
    } catch (_) {
      if (context.mounted) _showUnavailable(context);
    }
  }

  void _showUnavailable(BuildContext context) {
    if (context.mounted) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.prototypeTemporarilyUnavailable,
      );
    }
  }
}
