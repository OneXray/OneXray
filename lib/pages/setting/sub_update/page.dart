import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/sub_update/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/service/sub_update/state.dart';

class SubUpdatePage extends StatelessWidget {
  const SubUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubUpdateController(),
      child: BlocBuilder<SubUpdateController, SubUpdatePageState>(
        builder: (context, state) {
          final controller = context.read<SubUpdateController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.subUpdatePageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    SubUpdatePageState state,
    SubUpdateController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: SectionView(
                title: "",
                child: Column(
                  children: [
                    _enable(context, state, controller),
                    if (state.subUpdateState.enable)
                      _interval(context, state, controller),
                    _autoPing(context, state, controller),
                  ],
                ),
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _enable(
    BuildContext context,
    SubUpdatePageState state,
    SubUpdateController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.subUpdatePageEnable),
        Switch(
          value: state.subUpdateState.enable,
          onChanged: (value) => controller.updateEnable(value),
        ),
      ],
    );
  }

  Widget _interval(
    BuildContext context,
    SubUpdatePageState state,
    SubUpdateController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.subUpdatePageInterval),
        TextMenuPicker(
          title: "${state.subUpdateState.interval}",
          selections: SubUpdateInterval.values,
          callback: (value) => controller.updateInterval(value),
        ),
      ],
    );
  }

  Widget _autoPing(
    BuildContext context,
    SubUpdatePageState state,
    SubUpdateController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.subUpdatePageAutoPing),
        Switch(
          value: state.subUpdateState.autoPing,
          onChanged: (value) => controller.updateAutoPing(value),
        ),
      ],
    );
  }

  Widget _bottomButton(BuildContext context, SubUpdateController controller) {
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
