import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/preferences/controller.dart';
import 'package:onexray/pages/settings/app_icon/page.dart';
import 'package:onexray/pages/settings/desktop/controller.dart';
import 'package:onexray/pages/settings/language/page.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/button_progress.dart';
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
        return Scaffold(
          appBar: AppBar(title: Text(l10n.prototypeSettings)),
          body: SafeArea(
            child: BlocBuilder<AppEventBus, AppEventBusState>(
              builder: (context, preferences) {
                final mobile =
                    MediaQuery.sizeOf(context).width <=
                    AppLayout.mobileBreakpoint;
                final palette = ColorManager.palette(context);
                final rowHeight = mobile ? 43.0 : 56.0;
                final sectionGap = mobile ? 25.0 : 28.0;
                final appearance = SettingSection(
                  title: l10n.prototypeAppearance,
                  icon: LucideIcons.palette,
                  padding: EdgeInsets.zero,
                  dividerIndent: 0,
                  children: [
                    _ThemeOptions(
                      selected: preferences.themeCode,
                      onSelected: (theme) =>
                          controller.setTheme(context, theme),
                    ),
                    if (controller.showAppIcon)
                      SettingRow(
                        title: l10n.prototypeAppIcon,
                        value: appIconLabel(l10n, state.appIcon),
                        minHeight: mobile ? 52 : 56,
                        titleStyle: AppTypography.settingsRow,
                        valueStyle: AppTypography.settingsVersion.copyWith(
                          color: palette.mutedStrong,
                        ),
                        decorateLeading: false,
                        showChevron: true,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.compact),
                          child:
                              (AppPlatform.isMacOS
                                      ? state.appIcon.dockAssetImage
                                      : state.appIcon.assetImage)
                                  .image(width: 26, height: 26),
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
                  icon: LucideIcons.languages,
                  padding: EdgeInsets.zero,
                  children: [
                    SettingRow(
                      title: languageNativeLabel(
                        l10n,
                        preferences.languageCode,
                      ),
                      minHeight: rowHeight,
                      titleStyle: AppTypography.settingsRow,
                      showChevron: true,
                      onTap: () => controller.openSetting(
                        context,
                        AppSecondaryDestination.language,
                      ),
                    ),
                  ],
                );
                final startup = SettingSection(
                  title: l10n.prototypeStartup,
                  icon: LucideIcons.power,
                  padding: EdgeInsets.zero,
                  dividerIndent: 0,
                  children: [
                    _StartupSettingRow(
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
                  icon: LucideIcons.hardDrive,
                  padding: EdgeInsets.zero,
                  dividerIndent: 0,
                  children: [
                    SettingRow(
                      title: l10n.prototypeBackupRestore,
                      minHeight: rowHeight,
                      titleStyle: AppTypography.settingsRow,
                      showChevron: true,
                      onTap: state.clearingData
                          ? null
                          : () => controller.openSetting(
                              context,
                              AppSecondaryDestination.backup,
                            ),
                    ),
                    SettingRow(
                      title: l10n.prototypeClearData,
                      minHeight: rowHeight,
                      titleStyle: AppTypography.settingsDanger.copyWith(
                        color: palette.destructive,
                      ),
                      trailing: state.clearingData
                          ? const ButtonProgressIndicator(size: 20)
                          : null,
                      onTap: state.clearingData
                          ? null
                          : () => controller.clearData(context),
                    ),
                  ],
                );
                final about = SettingSection(
                  title: l10n.prototypeAbout,
                  icon: LucideIcons.info,
                  padding: EdgeInsets.zero,
                  dividerIndent: 0,
                  children: [
                    Semantics(
                      label: preferences.appUpdateInfo == null
                          ? null
                          : l10n.prototypeAboutUpdateAvailable,
                      child: SettingRow(
                        minHeight: rowHeight,
                        title: l10n.prototypeAboutOneXray,
                        titleStyle: AppTypography.settingsRow,
                        titleTrailing: preferences.appUpdateInfo == null
                            ? null
                            : const _UpdateDot(),
                        showChevron: true,
                        onTap: () => controller.openSetting(
                          context,
                          AppSecondaryDestination.aboutOneXray,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        _VersionRow(
                          label: l10n.prototypeAppVersion,
                          value: state.appVersion,
                          compact: true,
                        ),
                        _VersionRow(
                          label: 'Xray-core',
                          value: state.xrayVersion,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                );
                return SettingsPageScroll(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    mobile ? 12 : AppSpacing.page,
                    27,
                    mobile ? 12 : AppSpacing.page,
                    20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                        SizedBox(height: sectionGap),
                                        language,
                                        SizedBox(height: sectionGap),
                                        startup,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 56),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        data,
                                        SizedBox(height: sectionGap),
                                        about,
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  appearance,
                                  SizedBox(height: sectionGap),
                                  language,
                                  SizedBox(height: sectionGap),
                                  startup,
                                  SizedBox(height: sectionGap),
                                  data,
                                  SizedBox(height: sectionGap),
                                  about,
                                ],
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          10,
                          25,
                          10,
                          0,
                        ),
                        child: Text(
                          l10n.prototypeSettingsLocationNote,
                          style: AppTypography.settingsNote.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

class _ThemeOptions extends StatelessWidget {
  final ThemeCode selected;
  final ValueChanged<ThemeCode> onSelected;

  const _ThemeOptions({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final theme in ThemeCode.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: selected == theme,
                  child: Material(
                    color: selected == theme
                        ? palette.selectedSurface
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.compact),
                      side: BorderSide(
                        color: selected == theme
                            ? palette.primary
                            : Colors.transparent,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelected(theme),
                      child: Container(
                        constraints: BoxConstraints(
                          minHeight: mobile ? 45 : 47,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 5 : 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: selected == theme || theme == ThemeCode.dark
                              ? null
                              : BorderDirectional(
                                  end: BorderSide(color: palette.border),
                                ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              switch (theme) {
                                ThemeCode.system => LucideIcons.monitor,
                                ThemeCode.light => LucideIcons.sun,
                                ThemeCode.dark => LucideIcons.moon,
                              },
                              size: mobile ? 16 : 18,
                              color: selected == theme
                                  ? palette.primary
                                  : palette.foreground,
                            ),
                            SizedBox(width: mobile ? 6 : 8),
                            Flexible(
                              child: Text(
                                switch (theme) {
                                  ThemeCode.system => l10n.prototypeSystem,
                                  ThemeCode.light => l10n.prototypeLight,
                                  ThemeCode.dark => l10n.prototypeDark,
                                },
                                textAlign: TextAlign.center,
                                style:
                                    (mobile
                                            ? AppTypography
                                                  .settingsThemeOptionMobile
                                            : AppTypography.settingsThemeOption)
                                        .copyWith(
                                          color: selected == theme
                                              ? palette.primary
                                              : palette.foreground,
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StartupSettingRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _StartupSettingRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return SettingRow(
      title: title,
      subtitle: subtitle,
      minHeight: mobile ? 58 : 64,
      contentPadding: EdgeInsetsDirectional.symmetric(
        horizontal: mobile ? 13 : 14,
        vertical: mobile ? 7 : 9,
      ),
      titleStyle: mobile
          ? AppTypography.settingsFieldTitle
          : AppTypography.settingsRow,
      subtitleStyle: AppTypography.settingsHint.copyWith(
        color: ColorManager.secondaryText(context),
      ),
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: ShadSwitch(
        value: value,
        width: mobile ? 40 : 46,
        height: mobile ? 23 : 27,
        enabled: onChanged != null,
        onChanged: onChanged,
      ),
    );
  }
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
              _StartupSettingRow(
                title: l10n.prototypeLaunchAtLogin,
                subtitle: l10n.prototypeLaunchAtLoginHint,
                value: state.launchAtLogin.enabled,
                onChanged: state.launchToggleEnabled && !state.requiresApproval
                    ? (value) => controller.updateLaunchAtLogin(context, value)
                    : null,
              ),
              const Divider(height: 1),
              _StartupSettingRow(
                title: l10n.prototypeStartHidden,
                subtitle: l10n.prototypeStartHiddenHint,
                value: state.startHidden,
                onChanged: state.behaviorSettingsEnabled
                    ? (value) =>
                          controller.updateStartHidden(value, context: context)
                    : null,
              ),
              if (AppPlatform.isMacOS) ...[
                const Divider(height: 1),
                _StartupSettingRow(
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
              if (state.requiresApproval) ...[
                const Divider(height: 1),
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
                            child: ButtonProgress(
                              busy: state.changingLaunchAtLogin,
                              child: Text(l10n.prototypeCancelRequest),
                            ),
                          ),
                          TextButton(
                            onPressed: state.openingSystemSettings
                                ? null
                                : () => controller.openSystemSettings(context),
                            child: ButtonProgress(
                              busy: state.openingSystemSettings,
                              child: Text(l10n.prototypeOpenSystemSettings),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
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
              padding: const EdgeInsets.fromLTRB(14, 17, 14, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.prototypeAppInformation,
                    style: AppTypography.settingsDetailNote.copyWith(
                      color: ColorManager.secondaryText(context),
                    ),
                  ),
                  const SizedBox(height: 23),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: state.appIcon.assetImage.image(
                            width: 74,
                            height: 74,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text('OneXray', style: AppTypography.aboutBrandTitle),
                        const SizedBox(height: 9),
                        Text(
                          l10n.prototypeCrossPlatformXrayClient,
                          style: AppTypography.aboutBrandDescription.copyWith(
                            color: ColorManager.secondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 23),
                  SettingSection(
                    title: '',
                    padding: EdgeInsets.zero,
                    dividerIndent: 0,
                    children: [
                      _VersionRow(
                        label: l10n.prototypeAppVersion,
                        value: state.appVersion,
                        compact: true,
                      ),
                      _VersionRow(
                        label: 'Xray-core',
                        value: state.xrayVersion,
                        compact: true,
                      ),
                      BlocBuilder<AppEventBus, AppEventBusState>(
                        builder: (context, preferences) => SettingRow(
                          title: l10n.prototypeCheckAppUpdates,
                          minHeight: 64,
                          titleStyle: AppTypography.settingsRow,
                          subtitleStyle: AppTypography.settingsChoiceDetail,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 12,
                          ),
                          subtitle: preferences.appUpdateInfo == null
                              ? l10n.prototypeCheckNewVersions
                              : l10n.prototypeVersionAvailable(
                                  preferences.appUpdateInfo!.latestVersion,
                                ),
                          trailing: state.checkingUpdate
                              ? const ButtonProgressIndicator(size: 20)
                              : Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(LucideIcons.download, size: 18),
                                    if (preferences.appUpdateInfo != null)
                                      const Positioned(
                                        right: -4,
                                        top: -4,
                                        child: _UpdateDot(),
                                      ),
                                  ],
                                ),
                          onTap: state.checkingUpdate
                              ? null
                              : () => controller.checkUpdate(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 23),
                  SettingSection(
                    title: l10n.prototypeHelpCommunity,
                    headerInset: 0,
                    icon: LucideIcons.circleHelp,
                    padding: EdgeInsets.zero,
                    dividerIndent: 0,
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
                    padding: const EdgeInsets.only(top: 13),
                    child: Text(
                      l10n.prototypeAboutPrivacyNotice,
                      style: AppTypography.settingsDetailNote.copyWith(
                        color: ColorManager.secondaryText(context),
                      ),
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
  final bool compact;
  const _VersionRow({
    required this.label,
    required this.value,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return SettingRow(
        title: label,
        trailing: Text(
          value,
          textDirection: TextDirection.ltr,
          style: AppTypography.code,
        ),
      );
    }
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final color = ColorManager.palette(context).mutedStrong;
    return SettingRow(
      title: label,
      minHeight: mobile ? 42 : 53,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: 13,
        vertical: 8,
      ),
      titleStyle: AppTypography.settingsVersion.copyWith(color: color),
      trailing: Text(
        value,
        textDirection: TextDirection.ltr,
        style: AppTypography.settingsVersion.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final PreferencesLink link;
  const _LinkRow({required this.label, required this.icon, required this.link});
  @override
  Widget build(BuildContext context) => SettingRow(
    title: label,
    minHeight: 43,
    titleStyle: AppTypography.settingsRow,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    trailing: const Icon(LucideIcons.chevronRightDir, size: 17),
    onTap: () => context.read<PreferencesController>().openLink(context, link),
  );
}
