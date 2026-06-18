import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/app_update/dialog.dart';
import 'package:onexray/pages/geo_data/list/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/doc/helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingState {
  final String appVersion;
  final String xrayVersion;
  final bool checkingUpdate;

  const SettingState({
    this.appVersion = "",
    this.xrayVersion = "",
    this.checkingUpdate = false,
  });

  SettingState copyWith({
    String? appVersion,
    String? xrayVersion,
    bool? checkingUpdate,
  }) {
    return SettingState(
      appVersion: appVersion ?? this.appVersion,
      xrayVersion: xrayVersion ?? this.xrayVersion,
      checkingUpdate: checkingUpdate ?? this.checkingUpdate,
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
    context.push(RouterPath.tunSettingUI);
  }

  void gotoPing(BuildContext context) {
    context.push(RouterPath.ping);
  }

  void gotoAutoUpdate(BuildContext context) {
    context.push(RouterPath.autoUpdate);
  }

  void gotoGeoData(BuildContext context) {
    final params = GeoDataListParams(
      GeoDataListType.full,
      GeoDatCodesMode.show,
    );
    final path = RouterPath.geoDataList;
    context.push(path, extra: params);
  }

  final _enhancedRouting = Uri.parse("https://github.com/OneXray/Routing");

  Future<void> openEnhancedRouting(BuildContext context) async {
    try {
      await launchUrl(_enhancedRouting);
    } catch (e) {
      ygLogger("openEnhancedRouting error: $e");
    }
  }

  void gotoLog(BuildContext context) {
    context.push(RouterPath.log);
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

  void gotoBackup(BuildContext context) {
    context.push(RouterPath.backup);
  }

  void gotoAppIcon(BuildContext context) {
    context.push(RouterPath.appIcon);
  }

  void gotoToolbox(BuildContext context) {
    context.push(RouterPath.toolbox);
  }

  void gotoTheme(BuildContext context) {
    context.push(RouterPath.theme);
  }

  void gotoLanguage(BuildContext context) {
    context.push(RouterPath.language);
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

  final _email = Uri.parse("mailto:yuan@yuandev.net");

  Future<void> sendEmail(BuildContext context) async {
    try {
      await launchUrl(_email);
    } catch (e) {
      ygLogger("sendEmail error: $e");
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
