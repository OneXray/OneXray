import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/tun/on_demand_rule/controller.dart';
import 'package:onexray/pages/core/tun/on_demand_rule/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/tun_setting/enum.dart';

class OnDemandRulePage extends StatelessWidget {
  final OnDemandRuleParams params;

  const OnDemandRulePage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnDemandRuleController(params),
      child: BlocBuilder<OnDemandRuleController, OnDemandRulePageState>(
        builder: (context, state) {
          final controller = context.read<OnDemandRuleController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.onDemandRulePageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    OnDemandRulePageState state,
    OnDemandRuleController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _modeSection(context, state, controller),
                    if (state.ruleState.interfaceType ==
                        OnDemandRuleInterfaceType.wifi)
                      _ssidSection(context, state, controller),
                  ],
                ),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _modeSection(
    BuildContext context,
    OnDemandRulePageState state,
    OnDemandRuleController controller,
  ) {
    return SettingSection(
      title: "",
      children: [
        _mode(context, state, controller),
        _interfaceType(context, state, controller),
      ],
    );
  }

  Widget _mode(
    BuildContext context,
    OnDemandRulePageState state,
    OnDemandRuleController controller,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.onDemandRulePageMode,
      value: state.ruleState.mode.name,
      selections: OnDemandRuleMode.names,
      onSelected: (value) => controller.updateMode(value),
    );
  }

  Widget _interfaceType(
    BuildContext context,
    OnDemandRulePageState state,
    OnDemandRuleController controller,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.onDemandRulePageInterfaceType,
      value: state.ruleState.interfaceType.name,
      selections: OnDemandRuleInterfaceType.names,
      onSelected: (value) => controller.updateInterfaceType(value),
    );
  }

  Widget _ssidSection(
    BuildContext context,
    OnDemandRulePageState state,
    OnDemandRuleController controller,
  ) {
    final ssidsViews = state.ssids
        .mapIndexed(
          (index, ssid) => TextFieldActionSettingRow(
            controller: controller.ssidControllers[index],
            label: AppLocalizations.of(context)!.onDemandRulePageSSID,
            hintText: AppLocalizations.of(context)!.onDemandRulePageSSID,
            trailing: IconButton(
              onPressed: () => controller.deleteSsid(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.onDemandRulePageSSID,
          trailing: IconButton(
            onPressed: () => controller.appendSsid(),
            icon: const Icon(Icons.add),
          ),
        ),
        ...ssidsViews,
      ],
    );
  }

  Widget _bottomButton(
    BuildContext context,
    OnDemandRuleController controller,
  ) {
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
