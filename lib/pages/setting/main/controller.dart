import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/pages/geo_data/list/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/doc/helper.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingState {
  final String appVersion;
  final String xrayVersion;

  const SettingState({this.appVersion = "", this.xrayVersion = ""});

  SettingState copyWith({String? appVersion, String? xrayVersion}) {
    return SettingState(
      appVersion: appVersion ?? this.appVersion,
      xrayVersion: xrayVersion ?? this.xrayVersion,
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
    emit(state.copyWith(appVersion: appVersion, xrayVersion: xrayVersion));
  }

  void gotoTunSetting(BuildContext context) {
    context.push(RouterPath.tunSettingUI);
  }

  void gotoPing(BuildContext context) {
    context.push(RouterPath.ping);
  }

  void gotoSubUpdate(BuildContext context) {
    context.push(RouterPath.subUpdate);
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
