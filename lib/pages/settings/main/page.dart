import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/settings/main/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingPageTitle),
      ),
      body: const SafeArea(child: SettingContent()),
    );
  }
}

class SettingContent extends StatelessWidget {
  const SettingContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingController(),
      child: BlocBuilder<SettingController, SettingState>(
        builder: (context, state) {
          final controller = context.read<SettingController>();
          return _body(context, state, controller);
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
        child: ResponsiveContent(
          desktopMaxWidth: 1040,
          adaptiveBreakpoint: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 900) {
                    return _wideBody(context, state, controller);
                  }
                  return _compactBody(context, state, controller);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactBody(
    BuildContext context,
    SettingState state,
    SettingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dataSection(context, state, controller),
        _appSection(context, controller),
        _supportSection(context, controller),
        _versionSection(context, state),
        _footerTips(context),
      ],
    );
  }

  Widget _wideBody(
    BuildContext context,
    SettingState state,
    SettingController controller,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dataSection(context, state, controller),
              _versionSection(context, state),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _appSection(context, controller),
              _supportSection(context, controller),
              _footerTips(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dataSection(
    BuildContext context,
    SettingState state,
    SettingController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.settingPageSectionData,
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.autoUpdatePageTitle,
          leading: const Icon(Icons.update_outlined),
          onTap: () => controller.gotoAutoUpdate(context),
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.appUpdateCheck,
          leading: const Icon(Icons.system_update_outlined),
          onTap: state.checkingUpdate
              ? null
              : () => controller.checkUpdate(context),
          trailing: state.checkingUpdate
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(),
                )
              : null,
        ),
        _clearData(context, state, controller),
      ],
    );
  }

  Widget _clearData(
    BuildContext context,
    SettingState state,
    SettingController controller,
  ) {
    final errorColor = Theme.of(context).colorScheme.error;
    return SettingRow(
      title: AppLocalizations.of(context)!.settingPageClearData,
      subtitle: AppLocalizations.of(context)!.settingPageClearDataSubtitle,
      leading: Icon(Icons.delete_forever, color: errorColor),
      enabled: !state.clearingData,
      onTap: state.clearingData ? null : () => controller.clearData(context),
      trailing: state.clearingData
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(),
            )
          : Icon(Icons.chevron_right, color: errorColor),
    );
  }

  Widget _appSection(BuildContext context, SettingController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.settingPageSectionApp,
      children: [
        _backup(context, controller),
        if (AppPlatform.isIOS) _appIcon(context, controller),
        if (AppPlatform.isMacOS) _toolbox(context, controller),
        _theme(context, controller),
        _language(context, controller),
      ],
    );
  }

  Widget _backup(BuildContext context, SettingController controller) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.backupPageTitle,
      leading: const Icon(Icons.backup_outlined),
      onTap: () => controller.gotoBackup(context),
    );
  }

  Widget _appIcon(BuildContext context, SettingController controller) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.appIconPageTitle,
      leading: const Icon(Icons.apps_outlined),
      onTap: () => controller.gotoAppIcon(context),
    );
  }

  Widget _toolbox(BuildContext context, SettingController controller) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.toolboxPageTitle,
      leading: const Icon(Icons.build_outlined),
      onTap: () => controller.gotoToolbox(context),
    );
  }

  Widget _theme(BuildContext context, SettingController controller) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.themePageTitle,
      leading: const Icon(Icons.palette_outlined),
      onTap: () => controller.gotoTheme(context),
    );
  }

  Widget _language(BuildContext context, SettingController controller) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.languagePageTitle,
      leading: const Icon(Icons.translate_outlined),
      onTap: () => controller.gotoLanguage(context),
    );
  }

  Widget _supportSection(BuildContext context, SettingController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.settingPageSectionSupport,
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.settingPageDoc,
          leading: const Icon(Icons.menu_book_outlined),
          onTap: () => controller.openDoc(context),
        ),
        if (AppPlatform.isMobile || AppPlatform.isMacOS)
          NavigationSettingRow(
            title: AppLocalizations.of(context)!.settingPageReview,
            leading: const Icon(Icons.star_rate_outlined),
            onTap: () => controller.gotoReview(context),
          ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.settingPageTelegramChannel,
          leading: const Icon(Icons.send_outlined),
          onTap: () => controller.openTelegram(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.settingPageSubmitIssue,
          leading: const Icon(Icons.bug_report_outlined),
          onTap: () => controller.submitIssue(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.settingPageSourceCode,
          leading: const Icon(Icons.code_outlined),
          onTap: () => controller.openSourceCode(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.settingPageCredits,
          leading: const Icon(Icons.info_outline),
          onTap: () => controller.openCredits(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.settingPagePrivacy,
          leading: const Icon(Icons.privacy_tip_outlined),
          onTap: () => controller.openPrivacy(context),
        ),
      ],
    );
  }

  Widget _versionSection(BuildContext context, SettingState state) {
    return SettingSection(
      title: AppLocalizations.of(context)!.settingPageSectionVersion,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.settingPageAppVersion,
          leading: const Icon(Icons.apps_outlined),
          value: state.appVersion,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.settingPageXrayVersion,
          leading: const Icon(Icons.memory_outlined),
          value: state.xrayVersion,
        ),
      ],
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
        style: TextStyle(
          fontSize: 12,
          color: ColorManager.secondaryText(context),
        ),
      ),
    );
  }
}
