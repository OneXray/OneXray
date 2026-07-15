import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/auto_update/controller.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AutoUpdatePage extends StatelessWidget {
  const AutoUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AutoUpdateController(),
      child: BlocBuilder<AutoUpdateController, AutoUpdatePageState>(
        builder: (context, state) {
          final controller = context.read<AutoUpdateController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.autoUpdatePageTitle,
            onSave: () => controller.save(context),
            saveLabel: localizations.buttonSave,
            body: _body(context, state, controller),
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
    return SettingsPageScroll(
      desktopMaxWidth: 1040,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return _wideSections(context, state, controller);
          }
          return _compactSections(context, state, controller);
        },
      ),
    );
  }

  Widget _compactSections(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return Column(
      children: [
        _subscriptionSection(context, state, controller),
        _geoDataSection(context, state, controller),
      ],
    );
  }

  Widget _wideSections(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _subscriptionSection(context, state, controller)),
        Expanded(child: _geoDataSection(context, state, controller)),
      ],
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
        _subscriptionEnabled(context, state, controller),
        if (state.autoUpdateState.subscriptionEnabled)
          _subscriptionInterval(context, state, controller),
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

  Widget _subscriptionEnabled(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.autoUpdatePageEnable,
      leading: const Icon(LucideIcons.refreshCw),
      value: state.autoUpdateState.subscriptionEnabled,
      onChanged: (value) => controller.updateSubscriptionEnabled(value),
    );
  }

  Widget _subscriptionInterval(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.autoUpdatePageInterval,
      value: "${state.autoUpdateState.subscriptionInterval}",
      selections: AutoUpdateInterval.values,
      onSelected: (value) => controller.updateSubscriptionInterval(value),
    );
  }

  Widget _geoDataEnable(
    BuildContext context,
    AutoUpdatePageState state,
    AutoUpdateController controller,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.autoUpdatePageEnable,
      leading: const Icon(LucideIcons.database),
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
      leading: const Icon(LucideIcons.cloudDownload),
      value: state.autoUpdateState.geoDataUpdateAfterVpnConnected,
      onChanged: (value) =>
          controller.updateGeoDataUpdateAfterVpnConnected(value),
    );
  }
}
