import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/language/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/event_bus/enum.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LanguageController(),
      child: BlocBuilder<LanguageController, LanguageState>(
        builder: (context, state) {
          final controller = context.read<LanguageController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.languagePageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    LanguageState state,
    LanguageController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _languageSection(context, state, controller),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _languageSection(
    BuildContext context,
    LanguageState state,
    LanguageController controller,
  ) {
    final children = LanguageCode.values
        .map(
          (e) => SettingRow(
            title: "$e",
            onTap: () => controller.updateLanguageCode(e),
            trailing: Radio<LanguageCode>(value: e),
          ),
        )
        .toList();
    return RadioGroup<LanguageCode>(
      groupValue: state.languageCode,
      onChanged: (value) => controller.updateLanguageCode(value),
      child: SettingSection(title: "", children: children),
    );
  }

  Widget _bottomButton(BuildContext context, LanguageController controller) {
    return BottomView(
      child: Row(
        children: [
          Expanded(
            child: PrimaryBottomButton(
              title: AppLocalizations.of(context)!.buttonSave,
              callback: () => controller.save(context),
            ),
          ),
        ],
      ),
    );
  }
}
