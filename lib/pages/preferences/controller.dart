import 'package:flutter/material.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/doc/helper.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PreferencesPageState {
  final String appVersion;
  final String xrayVersion;
  const PreferencesPageState({this.appVersion = '—', this.xrayVersion = '—'});
}

enum PreferencesLink {
  documentation,
  community,
  feedback,
  source,
  credits,
  privacy,
}

class PreferencesController extends PageCubit<PreferencesPageState> {
  PreferencesController() : super(const PreferencesPageState()) {
    _readVersions();
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
    emit(
      PreferencesPageState(appVersion: appVersion, xrayVersion: xrayVersion),
    );
  }

  void openSetting(BuildContext context, AppSecondaryDestination destination) {
    context.goScoped(destination);
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
      PreferencesLink.community => Uri.parse('https://t.me/OneXrayApp'),
      PreferencesLink.feedback => Uri.parse(
        'https://github.com/OneXray/OneXray/issues/new',
      ),
      PreferencesLink.source => Uri.parse('https://github.com/OneXray/OneXray'),
      PreferencesLink.credits => DocURLHelper.creditsUri(),
      PreferencesLink.privacy => DocURLHelper.privacyUri(),
    };
    try {
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
