import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/auto_update/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/auto_update/state.dart';

class AutoUpdatePage extends StatelessWidget {
  const AutoUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AutoUpdateController(),
      child: BlocBuilder<AutoUpdateController, AutoUpdatePageState>(
        builder: (context, state) {
          final controller = context.read<AutoUpdateController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.autoUpdatePageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _subscriptionSection(context, state, controller),
                  _geoDataSection(context, state, controller),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _subscriptionSection(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.autoUpdatePageSubscription,
      children: [
        _enable(context, state, controller),
        if (state.autoUpdateState.enable) _interval(context, state, controller),
      ],
    );
  }

  Widget _geoDataSection(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.geoDataListPageTitle,
      children: [
        _geoDataEnable(context, state, controller),
        if (state.autoUpdateState.geoDataEnable)
          _geoDataUpdateAfterVpnConnected(context, state, controller),
        if (state.autoUpdateState.geoDataEnable)
          _geoDataInterval(context, state, controller),
      ],
    );
  }

  Widget _enable(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.autoUpdatePageEnable,
      value: state.autoUpdateState.enable,
      onChanged: (value) => controller.updateEnable(value),
    );
  }

  Widget _interval(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.autoUpdatePageInterval,
      value: "${state.autoUpdateState.interval}",
      selections: AutoUpdateInterval.values,
      onSelected: (value) => controller.updateInterval(value),
    );
  }

  Widget _geoDataEnable(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.autoUpdatePageEnable,
      value: state.autoUpdateState.geoDataEnable,
      onChanged: (value) => controller.updateGeoDataEnable(value),
    );
  }

  Widget _geoDataInterval(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.autoUpdatePageInterval,
      value: "${state.autoUpdateState.geoDataInterval}",
      selections: AutoUpdateInterval.values,
      onSelected: (value) => controller.updateGeoDataInterval(value),
    );
  }

  Widget _geoDataUpdateAfterVpnConnected(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(
        context,
      )!.autoUpdatePageGeoDataUpdateAfterVpnConnected,
      value: state.autoUpdateState.geoDataUpdateAfterVpnConnected,
      onChanged: (value) =>
          controller.updateGeoDataUpdateAfterVpnConnected(value),
    );
  }

  Widget _bottomButton(BuildContext context, AutoUpdateController controller) {
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
