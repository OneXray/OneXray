import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/theme/controller.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeController(),
      child: BlocBuilder<ThemeController, ThemePageState>(
        builder: (context, state) {
          final controller = context.read<ThemeController>();
          final l10n = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: l10n.themePageTitle,
            onSave: () => controller.save(context),
            saveLabel: l10n.buttonSave,
            body: ThemeChoiceView(
              selected: state.themeCode,
              onSelected: controller.updateThemeCode,
            ),
          );
        },
      ),
    );
  }
}

class ThemeChoiceView extends StatelessWidget {
  final ThemeCode selected;
  final ValueChanged<ThemeCode?> onSelected;

  const ThemeChoiceView({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      desktopMaxWidth: 720,
      child: SettingSection(
        title: "",
        children: ThemeCode.values.map((theme) {
          final (title, description, icon) = switch (theme) {
            ThemeCode.system => (
              l10n.themePageSystem,
              l10n.themePageSystemDescription,
              LucideIcons.monitorCog,
            ),
            ThemeCode.light => (
              l10n.themePageLight,
              l10n.themePageLightDescription,
              LucideIcons.sun,
            ),
            ThemeCode.dark => (
              l10n.themePageDark,
              l10n.themePageDarkDescription,
              LucideIcons.moon,
            ),
          };
          return SettingsChoiceRow(
            title: title,
            description: description,
            leading: Icon(icon),
            selected: selected == theme,
            onTap: () => onSelected(theme),
          );
        }).toList(),
      ),
    );
  }
}
