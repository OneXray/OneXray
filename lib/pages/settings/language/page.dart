import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/language/controller.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
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
          return PopScope(
            canPop: !state.saving,
            child: Scaffold(
              appBar: AppBar(
                title: Text(l10n.prototypeLanguage),
                leading: BackButton(
                  onPressed: () => controller.cancel(context),
                ),
              ),
              body: SafeArea(
                child: AbsorbPointer(
                  absorbing: state.saving,
                  child: LanguageChoiceView(
                    selected: state.languageCode,
                    onSelected: controller.updateLanguageCode,
                  ),
                ),
              ),
              bottomNavigationBar: PageActionBar(
                children: [
                  ShadButton.outline(
                    onPressed: state.saving
                        ? null
                        : () => controller.cancel(context),
                    child: Text(l10n.prototypeCancel),
                  ),
                  ShadButton(
                    onPressed: state.saving
                        ? null
                        : () => controller.save(context),
                    child: Text(l10n.prototypeSave),
                  ),
                ],
              ),
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
      child: Column(
        children: [
          SettingSection(
            title: "",
            children:
                const [
                  LanguageCode.system,
                  LanguageCode.zh,
                  LanguageCode.zhHant,
                  LanguageCode.en,
                  LanguageCode.ru,
                  LanguageCode.fa,
                ].map((language) {
                  return SettingsChoiceRow(
                    title: languageNativeLabel(l10n, language),
                    description: language == LanguageCode.system
                        ? null
                        : _title(l10n, language),
                    leading: const Icon(LucideIcons.globe2),
                    selected: selected == language,
                    onTap: () => onSelected(language),
                  );
                }).toList(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.prototypeLanguageSavedNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n, LanguageCode language) {
    return switch (language) {
      LanguageCode.system => l10n.prototypeFollowSystem,
      LanguageCode.en => l10n.prototypeEnglish,
      LanguageCode.ru => l10n.prototypeRussian,
      LanguageCode.fa => l10n.prototypePersian,
      LanguageCode.zh => l10n.prototypeSimplifiedChinese,
      LanguageCode.zhHant => l10n.prototypeTraditionalChinese,
    };
  }
}

String languageNativeLabel(AppLocalizations l10n, LanguageCode language) =>
    switch (language) {
      LanguageCode.system => l10n.prototypeFollowSystem,
      LanguageCode.zh => '简体中文',
      LanguageCode.zhHant => '繁體中文',
      LanguageCode.en => 'English',
      LanguageCode.ru => 'Русский',
      LanguageCode.fa => 'فارسی',
    };
