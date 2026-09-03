import 'package:flutter/material.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/language/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
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
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.prototypeLanguage),
              leading: BackButton(onPressed: () => controller.cancel(context)),
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
                  onPressed: () => controller.cancel(context),
                  child: Text(l10n.prototypeCancel),
                ),
                ShadButton(
                  enabled: !state.saving,
                  onPressed: state.saving
                      ? null
                      : () => controller.save(context),
                  child: ButtonProgress(
                    busy: state.saving,
                    child: Text(l10n.prototypeSave),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(14, 17, 14, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.prototypeChooseLanguage,
            style: AppTypography.settingsDetailNote.copyWith(
              color: ColorManager.secondaryText(context),
            ),
          ),
          const SizedBox(height: 23),
          ShadRadioGroup<LanguageCode>(
            axis: Axis.horizontal,
            initialValue: selected,
            onChanged: onSelected,
            items: [
              SettingSection(
                title: "",
                padding: EdgeInsets.zero,
                dividerIndent: 0,
                children:
                    const [
                      LanguageCode.system,
                      LanguageCode.zh,
                      LanguageCode.zhHant,
                      LanguageCode.en,
                      LanguageCode.ru,
                      LanguageCode.fa,
                    ].map((language) {
                      return ColoredBox(
                        color: selected == language
                            ? ColorManager.palette(context).accent
                            : Colors.transparent,
                        child: SettingRow(
                          title: languageNativeLabel(l10n, language),
                          titleTextDirection: language == LanguageCode.system
                              ? null
                              : language == LanguageCode.fa
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          minHeight: 78,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          titleStyle: AppTypography.settingsChoiceTitle,
                          subtitleWidget: language == LanguageCode.system
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Text(
                                    _title(l10n, language),
                                    style: AppTypography.settingsChoiceDetail
                                        .copyWith(
                                          color: ColorManager.secondaryText(
                                            context,
                                          ),
                                        ),
                                  ),
                                ),
                          leading: SizedBox(
                            width: 23,
                            child: Icon(
                              LucideIcons.languages,
                              size: 21,
                              color: ColorManager.palette(context).primary,
                            ),
                          ),
                          decorateLeading: false,
                          trailing: ShadRadio<LanguageCode>(
                            value: language,
                            decoration: selected == language
                                ? ShadDecoration(
                                    border: ShadBorder.all(
                                      color: ColorManager.palette(context)
                                          .primary,
                                      width: 1,
                                    ),
                                  )
                                : null,
                            radioPadding: EdgeInsets.zero,
                          ),
                          onTap: () => onSelected(language),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Text(
              l10n.prototypeLanguageSavedNotice,
              style: AppTypography.settingsDetailNote.copyWith(
                color: ColorManager.secondaryText(context),
              ),
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
