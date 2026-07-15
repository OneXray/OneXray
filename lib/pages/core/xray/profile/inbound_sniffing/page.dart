import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbound_sniffing/controller.dart';
import 'package:onexray/pages/core/xray/profile/inbound_sniffing/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class InboundSniffingPage extends StatelessWidget {
  final InboundSniffingParams params;

  const InboundSniffingPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundSniffingController(params),
      child: BlocBuilder<InboundSniffingController, InboundSniffingPageState>(
        builder: (context, state) {
          final controller = context.read<InboundSniffingController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.inboundSniffingPageTitle,
            onSave: () => controller.save(context),
            body: SettingsPageScroll(
              desktopMaxWidth: 900,
              child: Column(
                children: [
                  _behaviorSection(context, controller, state),
                  _protocolSection(context, controller, state),
                  SettingsResponsiveColumns(
                    firstFlex: 5,
                    secondFlex: 5,
                    first: [
                      _domainsExcludedSection(context, controller, state),
                    ],
                    second: [_ipsExcludedSection(context, controller, state)],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _behaviorSection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingPageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.inboundSniffingPageTitle,
      children: [
        SwitchSettingRow(
          leading: const Icon(LucideIcons.scanSearch),
          title: localizations.switchEnabled,
          value: state.sniffingState.enabled,
          onChanged: controller.updateEnabled,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.route),
          title: localizations.switchRouteOnly,
          value: state.sniffingState.routeOnly,
          onChanged: controller.updateRouteOnly,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.tags),
          title: localizations.inboundSniffingPageMetadataOnly,
          value: state.sniffingState.metadataOnly,
          onChanged: controller.updateMetadataOnly,
        ),
      ],
    );
  }

  Widget _protocolSection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingPageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.inboundSniffingPageDestOverride,
      separated: false,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SettingsChoiceChips<InboundSniffingDestOverride>(
              options: InboundSniffingDestOverride.values,
              selected: state.sniffingState.destOverride.toSet(),
              labelBuilder: (value) => value.name,
              onToggle: (value) => controller.updateDestOverride(
                !state.sniffingState.destOverride.contains(value),
                value,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _domainsExcludedSection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingPageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.inboundSniffingPageDomainsExcluded,
      action: IconButton(
        tooltip: localizations.buttonAdd,
        onPressed: controller.appendDomainsExcluded,
        icon: const Icon(LucideIcons.plus),
      ),
      children: state.sniffingState.domainsExcluded
          .mapIndexed(
            (index, _) => TextFieldActionSettingRow(
              controller: controller.domainsExcludedControllers[index],
              label: localizations.inboundSniffingPageDomainsExcluded,
              showLabel: false,
              hintText: localizations.inboundSniffingPageDomainsExcludedExample,
              trailing: IconButton(
                tooltip: localizations.menuDelete,
                onPressed: () =>
                    controller.deleteDomainsExcluded(context, index),
                icon: const Icon(LucideIcons.trash2),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _ipsExcludedSection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingPageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.inboundSniffingPageIpsExcluded,
      action: IconButton(
        tooltip: localizations.buttonAdd,
        onPressed: controller.appendIpsExcluded,
        icon: const Icon(LucideIcons.plus),
      ),
      children: state.sniffingState.ipsExcluded
          .mapIndexed(
            (index, _) => TextFieldActionSettingRow(
              controller: controller.ipsExcludedControllers[index],
              label: localizations.inboundSniffingPageIpsExcluded,
              showLabel: false,
              hintText: localizations.inboundSniffingPageIpsExcludedExample,
              trailing: IconButton(
                tooltip: localizations.menuDelete,
                onPressed: () => controller.deleteIpsExcluded(context, index),
                icon: const Icon(LucideIcons.trash2),
              ),
            ),
          )
          .toList(),
    );
  }
}
