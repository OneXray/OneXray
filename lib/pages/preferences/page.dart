import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/preferences/controller.dart';
import 'package:onexray/pages/settings/app_icon/page.dart';
import 'package:onexray/pages/settings/desktop/controller.dart';
import 'package:onexray/pages/settings/language/page.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PreferencesController(),
    child: BlocBuilder<PreferencesController, PreferencesPageState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final controller = context.read<PreferencesController>();
        return PopScope(
          canPop: !state.clearingData,
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.prototypeSettings)),
            body: SafeArea(
              child: BlocBuilder<AppEventBus, AppEventBusState>(
                builder: (context, preferences) {
                  final appearance = SettingSection(
                    title: l10n.prototypeAppearance,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final theme in ThemeCode.values)
                              ChoiceChip(
                                label: Text(switch (theme) {
                                  ThemeCode.system => l10n.prototypeSystem,
                                  ThemeCode.light => l10n.prototypeLight,
                                  ThemeCode.dark => l10n.prototypeDark,
                                }),
                                selected: preferences.themeCode == theme,
                                onSelected: (_) =>
                                    controller.setTheme(context, theme),
                              ),
                          ],
                        ),
                      ),
                      if (controller.showAppIcon)
                        NavigationSettingRow(
                          title: l10n.prototypeAppIcon,
                          value: appIconLabel(l10n, state.appIcon),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                (AppPlatform.isMacOS
                                        ? state.appIcon.dockAssetImage
                                        : state.appIcon.assetImage)
                                    .image(width: 32, height: 32),
                          ),
                          onTap: () => controller.openSetting(
                            context,
                            AppSecondaryDestination.appIcon,
                          ),
                        ),
                    ],
                  );
                  final language = SettingSection(
                    title: l10n.prototypeLanguage,
                    children: [
                      NavigationSettingRow(
                        title: languageNativeLabel(
                          l10n,
                          preferences.languageCode,
                        ),
                        leading: const Icon(LucideIcons.languages),
                        onTap: () => controller.openSetting(
                          context,
                          AppSecondaryDestination.language,
                        ),
                      ),
                    ],
                  );
                  final startup = SettingSection(
                    title: l10n.prototypeStartup,
                    children: [
                      SwitchSettingRow(
                        title: l10n.prototypeConnectAfterAppLaunch,
                        subtitle: l10n.prototypeConnectAfterAppLaunchHint,
                        value: state.connectOnLaunch,
                        onChanged: state.loading || state.saving
                            ? null
                            : (value) =>
                                  controller.setConnectOnLaunch(context, value),
                      ),
                      if (AppPlatform.isDesktop)
                        BlocProvider(
                          create: (_) => DesktopSettingsController(),
                          child: const _DesktopStartupRows(),
                        ),
                    ],
                  );
                  final data = SettingSection(
                    title: l10n.prototypeData,
                    children: [
                      SettingRow(
                        title: l10n.prototypeBackupRestore,
                        showChevron: true,
                        leading: const Icon(LucideIcons.archive),
                        onTap: state.clearingData
                            ? null
                            : () => controller.openSetting(
                                context,
                                AppSecondaryDestination.backup,
                              ),
                      ),
                      SettingRow(
                        title: l10n.prototypeClearData,
                        leading: Icon(
                          LucideIcons.trash2,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        trailing: state.clearingData
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        onTap: state.clearingData
                            ? null
                            : () => controller.clearData(context),
                      ),
                    ],
                  );
                  final about = SettingSection(
                    title: l10n.prototypeAbout,
                    children: [
                      Semantics(
                        label: preferences.appUpdateInfo == null
                            ? null
                            : l10n.prototypeAboutUpdateAvailable,
                        child: ListTile(
                          minTileHeight: 62,
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.prototypeAboutOneXray,
                                  style: AppTypography.rowTitle,
                                ),
                              ),
                              if (preferences.appUpdateInfo != null) ...[
                                const SizedBox(width: 8),
                                const _UpdateDot(),
                              ],
                            ],
                          ),
                          leading: const Icon(LucideIcons.info),
                          trailing: const Icon(LucideIcons.chevronRightDir),
                          onTap: () => controller.openSetting(
                            context,
                            AppSecondaryDestination.aboutOneXray,
                          ),
                        ),
                      ),
                      _VersionRow(
                        label: l10n.prototypeAppVersion,
                        value: state.appVersion,
                      ),
                      _VersionRow(label: 'Xray-core', value: state.xrayVersion),
                    ],
                  );
                  return SettingsPageScroll(
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) =>
                              constraints.maxWidth >= 850
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          appearance,
                                          language,
                                          startup,
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(children: [data, about]),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    appearance,
                                    language,
                                    startup,
                                    data,
                                    about,
                                  ],
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _DesktopStartupRows extends StatelessWidget {
  const _DesktopStartupRows();
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<DesktopSettingsController, DesktopSettingsPageState>(
        builder: (context, state) {
          final controller = context.read<DesktopSettingsController>();
          final l10n = AppLocalizations.of(context)!;
          return Column(
            children: [
              SwitchSettingRow(
                title: l10n.prototypeLaunchAtLogin,
                subtitle: l10n.prototypeLaunchAtLoginHint,
                value: state.launchAtLogin.enabled,
                onChanged: state.launchToggleEnabled
                    ? (value) => controller.updateLaunchAtLogin(context, value)
                    : null,
              ),
              if (state.requiresApproval)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.prototypeSystemApprovalRequired),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: state.changingLaunchAtLogin
                                ? null
                                : () => controller.updateLaunchAtLogin(
                                    context,
                                    false,
                                  ),
                            child: Text(l10n.prototypeCancelRequest),
                          ),
                          TextButton(
                            onPressed: () =>
                                controller.openSystemSettings(context),
                            child: Text(l10n.prototypeOpenSystemSettings),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              SwitchSettingRow(
                title: l10n.prototypeStartHidden,
                subtitle: l10n.prototypeStartHiddenHint,
                value: state.startHidden,
                onChanged: state.behaviorSettingsEnabled
                    ? (value) =>
                          controller.updateStartHidden(value, context: context)
                    : null,
              ),
              if (AppPlatform.isMacOS)
                SwitchSettingRow(
                  title: l10n.prototypeHideDockIcon,
                  subtitle: l10n.prototypeHideDockIconHint,
                  value: state.hideDockIcon,
                  onChanged: state.behaviorSettingsEnabled
                      ? (value) => controller.updateHideDockIcon(
                          value,
                          context: context,
                        )
                      : null,
                ),
            ],
          );
        },
      );
}

class AboutOneXrayPage extends StatelessWidget {
  const AboutOneXrayPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PreferencesController(),
    child: BlocBuilder<PreferencesController, PreferencesPageState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final controller = context.read<PreferencesController>();
        return Scaffold(
          appBar: AppBar(title: Text(l10n.prototypeAboutOneXray)),
          body: SafeArea(
            child: SettingsPageScroll(
              desktopMaxWidth: 760,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        state.appIcon.assetImage.image(width: 80, height: 80),
                        const SizedBox(height: 12),
                        Text(
                          'OneXray',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(l10n.prototypeCrossPlatformXrayClient),
                      ],
                    ),
                  ),
                  SettingSection(
                    title: '',
                    children: [
                      _VersionRow(
                        label: l10n.prototypeAppVersion,
                        value: state.appVersion,
                      ),
                      _VersionRow(label: 'Xray-core', value: state.xrayVersion),
                      BlocBuilder<AppEventBus, AppEventBusState>(
                        builder: (context, preferences) => SettingRow(
                          title: l10n.prototypeCheckAppUpdates,
                          subtitle: preferences.appUpdateInfo == null
                              ? null
                              : l10n.prototypeVersionAvailable(
                                  preferences.appUpdateInfo!.latestVersion,
                                ),
                          leading: const Icon(LucideIcons.download),
                          trailing: state.checkingUpdate
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : preferences.appUpdateInfo == null
                              ? null
                              : const _UpdateDot(),
                          onTap: state.checkingUpdate
                              ? null
                              : () => controller.checkUpdate(context),
                        ),
                      ),
                    ],
                  ),
                  SettingSection(
                    title: l10n.prototypeHelpCommunity,
                    children: [
                      _LinkRow(
                        label: l10n.prototypeDocumentation,
                        icon: LucideIcons.bookOpen,
                        link: PreferencesLink.documentation,
                      ),
                      _LinkRow(
                        label: l10n.prototypeCommunity,
                        icon: LucideIcons.send,
                        link: PreferencesLink.community,
                      ),
                      _LinkRow(
                        label: l10n.prototypeSendFeedback,
                        icon: LucideIcons.bug,
                        link: PreferencesLink.feedback,
                      ),
                      _LinkRow(
                        label: l10n.prototypeSourceCode,
                        icon: LucideIcons.code2,
                        link: PreferencesLink.source,
                      ),
                      _LinkRow(
                        label: l10n.prototypeAcknowledgements,
                        icon: LucideIcons.circleHelp,
                        link: PreferencesLink.credits,
                      ),
                      _LinkRow(
                        label: l10n.prototypePrivacyPolicy,
                        icon: LucideIcons.shieldCheck,
                        link: PreferencesLink.privacy,
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.prototypeNoDataUpload,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _UpdateDot extends StatelessWidget {
  const _UpdateDot();
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
    ),
  );
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String value;
  const _VersionRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => SettingRow(
    title: label,
    trailing: Text(
      value,
      textDirection: TextDirection.ltr,
      style: AppTypography.code,
    ),
  );
}

class _LinkRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final PreferencesLink link;
  const _LinkRow({required this.label, required this.icon, required this.link});
  @override
  Widget build(BuildContext context) => SettingRow(
    title: label,
    leading: Icon(icon),
    trailing: const Icon(LucideIcons.externalLink),
    onTap: () => context.read<PreferencesController>().openLink(context, link),
  );
}
