import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/main/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsPageTitle),
      ),
      body: const SafeArea(child: SettingsContent()),
    );
  }
}

class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsController(),
      child: BlocBuilder<SettingsController, SettingsPageState>(
        builder: (context, state) {
          final controller = context.read<SettingsController>();
          return SettingsOverviewView(
            state: state,
            showAppIcon: AppPlatform.isIOS || AppPlatform.isMacOS,
            useDockIconLabel: AppPlatform.isMacOS,
            showReview: AppPlatform.isMobile || AppPlatform.isMacOS,
            showDesktopSettings: AppPlatform.isDesktop,
            onAutoUpdate: () => controller.gotoAutoUpdate(context),
            onCheckUpdate: () => controller.checkUpdate(context),
            onClearData: () => controller.clearData(context),
            onBackup: () => controller.gotoBackup(context),
            onAppIcon: () => controller.gotoAppIcon(context),
            onTheme: () => controller.gotoTheme(context),
            onLanguage: () => controller.gotoLanguage(context),
            onConnectOnAppLaunchChanged: controller.updateConnectOnAppLaunch,
            onDesktopSettings: () => controller.gotoDesktopSettings(context),
            onDocumentation: () => controller.openDoc(context),
            onReview: () => controller.gotoReview(context),
            onTelegram: () => controller.openTelegram(context),
            onIssue: () => controller.submitIssue(context),
            onSourceCode: () => controller.openSourceCode(context),
            onCredits: () => controller.openCredits(context),
            onPrivacy: () => controller.openPrivacy(context),
          );
        },
      ),
    );
  }
}

class SettingsOverviewView extends StatelessWidget {
  final SettingsPageState state;
  final bool showAppIcon;
  final bool useDockIconLabel;
  final bool showReview;
  final bool showDesktopSettings;
  final VoidCallback onAutoUpdate;
  final VoidCallback onCheckUpdate;
  final VoidCallback onClearData;
  final VoidCallback onBackup;
  final VoidCallback onAppIcon;
  final VoidCallback onTheme;
  final VoidCallback onLanguage;
  final ValueChanged<bool> onConnectOnAppLaunchChanged;
  final VoidCallback onDesktopSettings;
  final VoidCallback onDocumentation;
  final VoidCallback onReview;
  final VoidCallback onTelegram;
  final VoidCallback onIssue;
  final VoidCallback onSourceCode;
  final VoidCallback onCredits;
  final VoidCallback onPrivacy;

  const SettingsOverviewView({
    super.key,
    required this.state,
    required this.showAppIcon,
    required this.useDockIconLabel,
    required this.showReview,
    required this.showDesktopSettings,
    required this.onAutoUpdate,
    required this.onCheckUpdate,
    required this.onClearData,
    required this.onBackup,
    required this.onAppIcon,
    required this.onTheme,
    required this.onLanguage,
    required this.onConnectOnAppLaunchChanged,
    required this.onDesktopSettings,
    required this.onDocumentation,
    required this.onReview,
    required this.onTelegram,
    required this.onIssue,
    required this.onSourceCode,
    required this.onCredits,
    required this.onPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsPageScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [_dataSection(context), _appSection(context)],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _versionSection(context),
                          _supportSection(context),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _dataSection(context),
                  _appSection(context),
                  _versionSection(context),
                  _supportSection(context),
                ],
              );
            },
          ),
          _footer(context),
        ],
      ),
    );
  }

  Widget _dataSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.settingsPageSectionData,
      children: [
        NavigationSettingRow(
          title: l10n.autoUpdatePageTitle,
          subtitle: l10n.settingsPageAutoUpdateDescription,
          leading: const Icon(LucideIcons.refreshCw),
          onTap: onAutoUpdate,
        ),
        SettingRow(
          title: l10n.appUpdateCheck,
          subtitle: l10n.settingsPageCheckUpdateDescription,
          leading: const Icon(LucideIcons.download),
          onTap: state.checkingUpdate ? null : onCheckUpdate,
          trailing: state.checkingUpdate
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.chevronRight),
        ),
        _clearDataRow(context),
      ],
    );
  }

  Widget _clearDataRow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;
    return SettingRow(
      title: l10n.settingsPageClearData,
      subtitle: l10n.settingsPageClearDataSubtitle,
      leading: Icon(LucideIcons.trash2, color: errorColor),
      enabled: !state.clearingData,
      onTap: state.clearingData ? null : onClearData,
      trailing: state.clearingData
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(LucideIcons.chevronRight, color: errorColor),
    );
  }

  Widget _appSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.settingsPageSectionApp,
      children: [
        SwitchSettingRow(
          title: l10n.settingsPageConnectOnLaunch,
          subtitle: l10n.settingsPageConnectOnLaunchDescription,
          leading: const Icon(LucideIcons.power),
          value: state.connectOnAppLaunch,
          onChanged: state.loadingConnectOnAppLaunch
              ? null
              : onConnectOnAppLaunchChanged,
        ),
        if (showDesktopSettings)
          NavigationSettingRow(
            title: l10n.settingsPageDesktop,
            subtitle: l10n.settingsPageDesktopDescription,
            leading: const Icon(LucideIcons.monitorCog),
            onTap: onDesktopSettings,
          ),
        NavigationSettingRow(
          title: l10n.backupPageTitle,
          subtitle: l10n.settingsPageBackupDescription,
          leading: const Icon(LucideIcons.archive),
          onTap: onBackup,
        ),
        if (showAppIcon)
          NavigationSettingRow(
            title: useDockIconLabel
                ? l10n.dockIconPageTitle
                : l10n.appIconPageTitle,
            subtitle: useDockIconLabel
                ? l10n.dockIconPageDescription
                : l10n.settingsPageAppIconDescription,
            leading: const Icon(LucideIcons.sparkles),
            onTap: onAppIcon,
          ),
        NavigationSettingRow(
          title: l10n.themePageTitle,
          subtitle: l10n.settingsPageThemeDescription,
          leading: const Icon(LucideIcons.palette),
          onTap: onTheme,
        ),
        NavigationSettingRow(
          title: l10n.languagePageTitle,
          subtitle: l10n.settingsPageLanguageDescription,
          leading: const Icon(LucideIcons.languages),
          onTap: onLanguage,
        ),
      ],
    );
  }

  Widget _versionSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.settingsPageSectionVersion,
      children: [
        SettingRow(
          title: l10n.settingsPageAppVersion,
          leading: const Icon(LucideIcons.smartphone),
          value: state.appVersion,
        ),
        SettingRow(
          title: l10n.settingsPageXrayVersion,
          leading: const Icon(LucideIcons.appWindow),
          value: state.xrayVersion,
        ),
      ],
    );
  }

  Widget _supportSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.settingsPageSectionSupport,
      children: [
        _externalRow(
          l10n.settingsPageDoc,
          LucideIcons.bookOpen,
          onDocumentation,
        ),
        if (showReview)
          _externalRow(l10n.settingsPageReview, LucideIcons.star, onReview),
        _externalRow(
          l10n.settingsPageTelegramChannel,
          LucideIcons.send,
          onTelegram,
        ),
        _externalRow(l10n.settingsPageSubmitIssue, LucideIcons.bug, onIssue),
        _externalRow(
          l10n.settingsPageSourceCode,
          LucideIcons.code2,
          onSourceCode,
        ),
        _externalRow(
          l10n.settingsPageCredits,
          LucideIcons.circleHelp,
          onCredits,
        ),
        _externalRow(
          l10n.settingsPagePrivacy,
          LucideIcons.shieldCheck,
          onPrivacy,
        ),
      ],
    );
  }

  Widget _externalRow(String title, IconData icon, VoidCallback onTap) {
    return SettingRow(
      title: title,
      leading: Icon(icon),
      trailing: const Icon(LucideIcons.externalLink),
      onTap: onTap,
    );
  }

  Widget _footer(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
      child: Text(
        AppLocalizations.of(context)!.settingsPageFooterTips,
        style: AppTypography.supporting.copyWith(
          color: ColorManager.secondaryText(context),
        ),
      ),
    );
  }
}
