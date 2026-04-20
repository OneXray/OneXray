import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/main/controller.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/text_action_row.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingController(),
      child: BlocBuilder<SettingController, SettingState>(
        builder: (context, state) {
          final controller = context.read<SettingController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.settingPageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SettingState state,
    SettingController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tunSection(context, state, controller),
            _backupSection(context, controller),
            _aboutSection(context, controller),
            _footerTips(context),
          ],
        ),
      ),
    );
  }

  Widget _tunSection(
    BuildContext context,
    SettingState state,
    SettingController controller,
  ) {
    final appVersion =
        "${AppLocalizations.of(context)!.settingPageAppVersion}${state.appVersion}";
    final xrayVersion =
        "${AppLocalizations.of(context)!.settingPageXrayVersion}${state.xrayVersion}";
    return SectionView(
      title: "$appVersion\n$xrayVersion",
      level: SectionLevel.none,
      child: Column(
        children: [
          TextActionRow(
            title: AppLocalizations.of(context)!.tunSettingUIPageTitle,
            detail: "",
            onTap: () => controller.gotoTunSetting(context),
          ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.pingPageTitle,
            detail: "",
            onTap: () => controller.gotoPing(context),
          ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.subUpdatePageTitle,
            detail: "",
            onTap: () => controller.gotoSubUpdate(context),
          ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.geoDataListPageTitle,
            detail: "",
            onTap: () => controller.gotoGeoData(context),
          ),
          if (!AppPlatform.isIOS) Divider(),
          if (!AppPlatform.isIOS)
            TextActionRow(
              title: AppLocalizations.of(context)!.settingPageEnhancedRouting,
              detail: "",
              onTap: () => controller.openEnhancedRouting(context),
            ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.logPageTitle,
            detail: "",
            onTap: () => controller.gotoLog(context),
          ),
        ],
      ),
    );
  }

  Widget _backupSection(BuildContext context, SettingController controller) {
    return SectionView(
      title: "",
      level: SectionLevel.none,
      child: Column(
        children: [
          _backup(context, controller),
          if (AppPlatform.isIOS) Divider(),
          if (AppPlatform.isIOS) _appIcon(context, controller),
          if (AppPlatform.isMacOS) Divider(),
          if (AppPlatform.isMacOS) _toolbox(context, controller),
          Divider(),
          _theme(context, controller),
          Divider(),
          _language(context, controller),
        ],
      ),
    );
  }

  Widget _backup(BuildContext context, SettingController controller) {
    return TextActionRow(
      title: AppLocalizations.of(context)!.backupPageTitle,
      detail: "",
      onTap: () => controller.gotoBackup(context),
    );
  }

  Widget _appIcon(BuildContext context, SettingController controller) {
    return TextActionRow(
      title: AppLocalizations.of(context)!.appIconPageTitle,
      detail: "",
      onTap: () => controller.gotoAppIcon(context),
    );
  }

  Widget _toolbox(BuildContext context, SettingController controller) {
    return TextActionRow(
      title: AppLocalizations.of(context)!.toolboxPageTitle,
      detail: "",
      onTap: () => controller.gotoToolbox(context),
    );
  }

  Widget _theme(BuildContext context, SettingController controller) {
    return TextActionRow(
      title: AppLocalizations.of(context)!.themePageTitle,
      detail: "",
      onTap: () => controller.gotoTheme(context),
    );
  }

  Widget _language(BuildContext context, SettingController controller) {
    return TextActionRow(
      title: AppLocalizations.of(context)!.languagePageTitle,
      detail: "",
      onTap: () => controller.gotoLanguage(context),
    );
  }

  Widget _aboutSection(BuildContext context, SettingController controller) {
    return SectionView(
      title: "",
      level: SectionLevel.none,
      child: Column(
        children: [
          TextActionRow(
            title: AppLocalizations.of(context)!.settingPageDoc,
            detail: "",
            onTap: () => controller.openDoc(context),
          ),
          if (AppPlatform.isMobile || AppPlatform.isMacOS) Divider(),
          if (AppPlatform.isMobile || AppPlatform.isMacOS)
            TextActionRow(
              title: AppLocalizations.of(context)!.settingPageReview,
              detail: "",
              onTap: () => controller.gotoReview(context),
            ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.settingPageTelegramChannel,
            detail: "",
            onTap: () => controller.openTelegram(context),
          ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.settingPageEmail,
            detail: "",
            onTap: () => controller.sendEmail(context),
          ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.settingPageSubmitIssue,
            detail: "",
            onTap: () => controller.submitIssue(context),
          ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.settingPageSourceCode,
            detail: "",
            onTap: () => controller.openSourceCode(context),
          ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.settingPageCredits,
            detail: "",
            onTap: () => controller.openCredits(context),
          ),
          Divider(),
          TextActionRow(
            title: AppLocalizations.of(context)!.settingPagePrivacy,
            detail: "",
            onTap: () => controller.openPrivacy(context),
          ),
        ],
      ),
    );
  }

  Widget _footerTips(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 16.0,
        end: 16.0,
        bottom: 16,
      ),
      child: Text(
        AppLocalizations.of(context)!.settingPageFooterTips,
        style: const TextStyle(fontSize: 12.0, color: Colors.grey),
      ),
    );
  }
}
