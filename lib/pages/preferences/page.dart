import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/preferences/controller.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (_) => PreferencesController(),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.prototypeSettings)),
        body: SafeArea(
          child: BlocBuilder<PreferencesController, PreferencesPageState>(
            builder: (context, state) {
              final controller = context.read<PreferencesController>();
              return BlocBuilder<AppEventBus, AppEventBusState>(
                builder: (context, preferences) => SettingsPageScroll(
                  child: Column(
                    children: [
                      SettingSection(
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
                              leading: const Icon(LucideIcons.sparkles),
                              onTap: () => controller.openSetting(
                                context,
                                AppSecondaryDestination.appIcon,
                              ),
                            ),
                        ],
                      ),
                      SettingSection(
                        title: l10n.prototypeLanguage,
                        children: [
                          NavigationSettingRow(
                            title: l10n.prototypeInterfaceLanguage,
                            value: preferences.languageCode.toString(),
                            leading: const Icon(LucideIcons.languages),
                            onTap: () => controller.openSetting(
                              context,
                              AppSecondaryDestination.language,
                            ),
                          ),
                        ],
                      ),
                      SettingSection(
                        title: l10n.prototypeAbout,
                        children: [
                          _VersionRow(
                            label: l10n.prototypeAppVersion,
                            value: state.appVersion,
                          ),
                          _VersionRow(
                            label: 'Xray-core',
                            value: state.xrayVersion,
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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: Text(
                          l10n.prototypeNoDataUpload,
                          style: AppTypography.supporting,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  final String label;
  final String value;
  const _VersionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => SettingRow(
    title: label,
    subtitleWidget: Text(
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
