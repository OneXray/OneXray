import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/language/controller.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LanguageController(),
      child: BlocBuilder<LanguageController, LanguagePageState>(
        builder: (context, state) {
          final controller = context.read<LanguageController>();
          final l10n = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: l10n.languagePageTitle,
            onSave: () => controller.save(context),
            saveLabel: l10n.buttonSave,
            body: LanguageChoiceView(
              selected: state.languageCode,
              onSelected: controller.updateLanguageCode,
            ),
          );
        },
      ),
    );
  }
}

class LanguageChoiceView extends StatelessWidget {
  final LanguageCode selected;
  final ValueChanged<LanguageCode?> onSelected;

  const LanguageChoiceView({
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
        children: LanguageCode.values.map((language) {
          return SettingsChoiceRow(
            title: _title(l10n, language),
            leading: const Icon(LucideIcons.globe2),
            selected: selected == language,
            onTap: () => onSelected(language),
          );
        }).toList(),
      ),
    );
  }

  String _title(AppLocalizations l10n, LanguageCode language) {
    return switch (language) {
      LanguageCode.system => l10n.languagePageSystem,
      LanguageCode.en => l10n.languagePageEnglish,
      LanguageCode.ru => l10n.languagePageRussian,
      LanguageCode.fa => l10n.languagePagePersian,
      LanguageCode.zh => l10n.languagePageChinese,
      LanguageCode.zhHant => l10n.languagePageTraditionalChinese,
    };
  }
}
