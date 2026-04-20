import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/theme/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/service/event_bus/enum.dart';

class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeController(),
      child: BlocBuilder<ThemeController, ThemeState>(
        builder: (context, state) {
          final controller = context.read<ThemeController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.themePageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ThemeState state,
    ThemeController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _themeSection(context, state, controller),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _themeSection(
    BuildContext context,
    ThemeState state,
    ThemeController controller,
  ) {
    final children = ThemeCode.values
        .map((e) => RadioListTile(value: e, title: Text("$e")))
        .toList();
    return SectionView(
      title: "",
      child: RadioGroup<ThemeCode>(
        groupValue: state.themeCode,
        onChanged: (value) => controller.updateThemeCode(value),
        child: Column(children: children),
      ),
    );
  }

  Widget _bottomButton(BuildContext context, ThemeController controller) {
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
