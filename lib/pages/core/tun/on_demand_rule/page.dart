import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/tun/on_demand_rule/controller.dart';
import 'package:onexray/pages/core/tun/on_demand_rule/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/tun_settings/enum.dart';

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
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.onDemandRulePageTitle,
            onSave: () => controller.save(context),
            body: _body(context, state, controller),
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
    return SettingsPageScroll(
      desktopMaxWidth: 760,
      child: Column(
        children: [
          _modeSection(context, state, controller),
          if (state.ruleState.interfaceType == OnDemandRuleInterfaceType.wifi)
            _ssidSection(context, state, controller),
        ],
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
      leading: const Icon(LucideIcons.zap),
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
      leading: const Icon(LucideIcons.wifi),
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
            showLabel: false,
            hintText: AppLocalizations.of(context)!.onDemandRulePageSSID,
            trailing: IconButton(
              onPressed: () => controller.deleteSsid(context, index),
              icon: const Icon(LucideIcons.trash2),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.wifi),
          title: AppLocalizations.of(context)!.onDemandRulePageSSID,
          trailing: IconButton(
            onPressed: () => controller.appendSsid(),
            icon: const Icon(LucideIcons.plus),
          ),
        ),
        ...ssidsViews,
      ],
    );
  }
}
