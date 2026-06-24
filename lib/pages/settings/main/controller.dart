import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/app_update/dialog.dart';
import 'package:onexray/pages/core/geo_data/list/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/data_cleanup/service.dart';
import 'package:onexray/service/doc/helper.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingState {
  final String appVersion;
  final String xrayVersion;
  final bool checkingUpdate;
  final bool clearingData;

  const SettingState({
    this.appVersion = "",
    this.xrayVersion = "",
    this.checkingUpdate = false,
    this.clearingData = false,
  });

  SettingState copyWith({
    String? appVersion,
    String? xrayVersion,
    bool? checkingUpdate,
    bool? clearingData,
  }) {
    return SettingState(
      appVersion: appVersion ?? this.appVersion,
      xrayVersion: xrayVersion ?? this.xrayVersion,
      checkingUpdate: checkingUpdate ?? this.checkingUpdate,
      clearingData: clearingData ?? this.clearingData,
    );
  }
}

class SettingController extends Cubit<SettingState> {
  SettingController() : super(const SettingState()) {
    _readVersion();
  }

  Future<void> _readVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
    final xrayVersion = await AppHostApi().xrayVersion();
    if (!isClosed) {
      emit(state.copyWith(appVersion: appVersion, xrayVersion: xrayVersion));
    }
  }

  void gotoTunSetting(BuildContext context) {
    context.goScoped(AppSecondaryDestination.tun);
  }

  void gotoPing(BuildContext context) {
    context.goScoped(AppSecondaryDestination.ping);
  }

  void gotoAutoUpdate(BuildContext context) {
    context.goScoped(AppSecondaryDestination.autoUpdate);
  }

  void gotoGeoData(BuildContext context) {
    final params = GeoDataListParams(
      GeoDataListType.full,
      GeoDatCodesMode.show,
    );
    context.goScoped(AppSecondaryDestination.geoData, extra: params);
  }

  void gotoLog(BuildContext context) {
    context.goScoped(AppSecondaryDestination.logs);
  }

  Future<void> checkUpdate(BuildContext context) async {
    if (state.checkingUpdate) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.runningAndWait,
      );
      return;
    }
    emit(state.copyWith(checkingUpdate: true));
    try {
      final result = await AppUpdateService().checkForUpdate();
      if (!context.mounted) {
        return;
      }
      await _handleUpdateResult(context, result, showUpToDate: true);
    } finally {
      if (!isClosed) {
        emit(state.copyWith(checkingUpdate: false));
      }
    }
  }

  Future<void> _handleUpdateResult(
    BuildContext context,
    AppUpdateCheckResult result, {
    required bool showUpToDate,
  }) async {
    switch (result.status) {
      case AppUpdateCheckStatus.available:
        final updateInfo = result.updateInfo;
        if (updateInfo != null) {
          await _showUpdateDialog(context, updateInfo);
        }
      case AppUpdateCheckStatus.upToDate:
        if (showUpToDate) {
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.appUpdateAlreadyLatest,
          );
        }
      case AppUpdateCheckStatus.failed:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.appUpdateCheckFailed,
        );
    }
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    AppUpdateInfo updateInfo,
  ) async {
    await AppUpdateDialog.show(context, updateInfo);
  }

  Future<void> clearData(BuildContext context) async {
    final eventBus = AppEventBus.instance;
    if (state.clearingData || eventBus.state.downloading) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.runningAndWait,
      );
      return;
    }

    final confirmed = await _showClearDataDialog(context);
    if (confirmed != true || !context.mounted) {
      return;
    }

    emit(state.copyWith(clearingData: true));
    eventBus.updateDownloading(true);
    var success = false;
    try {
      success = await AppDataCleanupService().clearFromSettings();
    } finally {
      eventBus.updateDownloading(false);
      if (!isClosed) {
        emit(state.copyWith(clearingData: false));
      }
    }

    if (!context.mounted) {
      return;
    }

    final localizations = AppLocalizations.of(context)!;
    ContextAlert.showToast(
      context,
      localizations.actionResult(
        localizations.settingPageClearData,
        success ? localizations.resultSuccess : localizations.resultFailed,
      ),
    );
    if (success) {
      context.goPrimaryRoot(AppPrimaryRoute.home);
    }
  }

  Future<bool?> _showClearDataDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.settingPageClearDataDialogTitle),
        content: Text(localizations.settingPageClearDataDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.buttonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.buttonOK),
          ),
        ],
      ),
    );
  }

  void gotoBackup(BuildContext context) {
    context.goScoped(AppSecondaryDestination.backup);
  }

  void gotoAppIcon(BuildContext context) {
    context.goScoped(AppSecondaryDestination.appIcon);
  }

  void gotoToolbox(BuildContext context) {
    context.goScoped(AppSecondaryDestination.toolbox);
  }

  void gotoTheme(BuildContext context) {
    context.goScoped(AppSecondaryDestination.theme);
  }

  void gotoLanguage(BuildContext context) {
    context.goScoped(AppSecondaryDestination.language);
  }

  Future<void> openDoc(BuildContext context) async {
    try {
      await launchUrl(DocURLHelper.docUri());
    } catch (e) {
      ygLogger("openDoc error: $e");
    }
  }

  Future<void> gotoReview(BuildContext context) async {
    final inAppReview = InAppReview.instance;
    if (await inAppReview.isAvailable()) {
      inAppReview.requestReview();
    }
  }

  final _telegramChannel = Uri.parse("https://t.me/OneXrayApp");

  Future<void> openTelegram(BuildContext context) async {
    try {
      await launchUrl(_telegramChannel);
    } catch (e) {
      ygLogger("openTelegram error: $e");
    }
  }

  final _githubIssue = Uri.parse(
    "https://github.com/OneXray/OneXray/issues/new",
  );

  Future<void> submitIssue(BuildContext context) async {
    try {
      await launchUrl(_githubIssue);
    } catch (e) {
      ygLogger("submitIssue error: $e");
    }
  }

  final _github = Uri.parse("https://github.com/OneXray/OneXray");
  Future<void> openSourceCode(BuildContext context) async {
    try {
      await launchUrl(_github);
    } catch (e) {
      ygLogger("openSourceCode error: $e");
    }
  }

  Future<void> openCredits(BuildContext context) async {
    try {
      await launchUrl(DocURLHelper.creditsUri());
    } catch (e) {
      ygLogger("openCredits error: $e");
    }
  }

  Future<void> openPrivacy(BuildContext context) async {
    try {
      await launchUrl(DocURLHelper.privacyUri());
    } catch (e) {
      ygLogger("openPrivacy error: $e");
    }
  }
}
