import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/launch/first_run/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/service/xray/setting/enum.dart';

class FirstRunPage extends StatelessWidget {
  const FirstRunPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FirstRunController(),
      child: BlocBuilder<FirstRunController, FirstRunState>(
        builder: (context, state) {
          final controller = context.read<FirstRunController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.firstRunPageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    FirstRunState state,
    FirstRunController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _countrySection(context, state, controller),
                  if (AppPlatform.isWindows || AppPlatform.isLinux)
                    _interfaceSection(context, state, controller),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _countrySection(
    BuildContext context,
    FirstRunState state,
    FirstRunController controller,
  ) {
    final cells = SimpleCountry.values
        .map((e) => RadioListTile<SimpleCountry>(value: e, title: Text(e.name)))
        .toList();
    return SectionView(
      title: AppLocalizations.of(context)!.firstRunPageCountrySection,
      child: RadioGroup<SimpleCountry>(
        groupValue: state.country,
        onChanged: (value) => controller.updateCountry(value),
        child: Column(children: cells),
      ),
    );
  }

  Widget _interfaceSection(
    BuildContext context,
    FirstRunState state,
    FirstRunController controller,
  ) {
    final cells = state.interfaces.map((e) {
      final name = e.name;
      final address = e.addresses.map((address) => address.address).join("\n");
      return RadioListTile<String>(
        value: name,
        title: Text(name),
        subtitle: Text(address),
      );
    }).toList();
    return SectionView(
      title: AppLocalizations.of(context)!.firstRunPageInterfaceSection,
      child: RadioGroup<String>(
        groupValue: state.interface,
        onChanged: (value) => controller.updateInterface(value),
        child: Column(children: cells),
      ),
    );
  }

  Widget _bottomButton(BuildContext context, FirstRunController controller) {
    return BottomView(
      child: Row(
        children: [
          Expanded(
            child: PrimaryBottomButton(
              title: AppLocalizations.of(context)!.buttonNextStep,
              callback: () => controller.nextStep(context),
            ),
          ),
        ],
      ),
    );
  }
}
