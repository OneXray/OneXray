import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule/controller.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/routing_rule_state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RoutingRulePage extends StatelessWidget {
  final RoutingRuleParams params;

  const RoutingRulePage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoutingRuleController(params),
      child: BlocBuilder<RoutingRuleController, RoutingRulePageState>(
        builder: (context, state) {
          final controller = context.read<RoutingRuleController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.routingRulePageTitle,
            onSave: () => controller.save(context),
            body: SettingsPageScroll(
              desktopMaxWidth: 980,
              child: Column(
                children: [
                  _ruleSection(context, controller, state),
                  SettingsResponsiveColumns(
                    firstFlex: 5,
                    secondFlex: 5,
                    first: [
                      _destinationSection(context, controller, state),
                      _sourceSection(context, controller, state),
                    ],
                    second: [
                      _inboundSection(context, controller, state),
                      _trafficSection(context, controller, state),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ruleSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRulePageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.routingRulePageSectionOutput,
      children: [
        TextFieldSettingRow(
          controller: controller.ruleTagController,
          label: localizations.routingRulePageRuleTag,
          hintText: localizations.routingRulePageRuleTag,
        ),
        SelectSettingRow<String>(
          leading: const Icon(LucideIcons.route),
          title: localizations.routingRulePageOutboundTag,
          value: state.ruleState.outboundTag,
          selections: state.outboundTags,
          onSelected: controller.updateOutboundTag,
        ),
      ],
    );
  }

  Widget _destinationSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRulePageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        _textListSection(
          context: context,
          title: localizations.routingRulePageDomain,
          hintText: localizations.routingRulePageDomainExample,
          controllers: controller.domainControllers,
          onAdd: controller.appendDomain,
          onImport: () => controller.importDomain(context),
          onDelete: (index) => controller.deleteDomain(context, index),
        ),
        _textListSection(
          context: context,
          title: localizations.routingRulePageIp,
          hintText: localizations.routingRulePageIpExample,
          controllers: controller.ipControllers,
          onAdd: controller.appendIp,
          onImport: () => controller.importIp(context),
          onDelete: (index) => controller.deleteIp(context, index),
        ),
        SettingSection(
          title: localizations.routingRulePageSectionPort,
          children: [
            TextFieldSettingRow(
              controller: controller.portController,
              label: localizations.routingRulePagePort,
              hintText: localizations.routingRulePagePortExample,
            ),
          ],
        ),
      ],
    );
  }

  Widget _sourceSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRulePageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        _textListSection(
          context: context,
          title: localizations.routingRulePageSourceIP,
          hintText: localizations.routingRulePageIpExample,
          controllers: controller.sourceIPControllers,
          onAdd: controller.appendSourceIP,
          onDelete: (index) => controller.deleteSourceIP(context, index),
        ),
        SettingSection(
          title: localizations.routingRulePageSectionSourceIP,
          children: [
            TextFieldSettingRow(
              controller: controller.sourcePortController,
              label: localizations.routingRulePageSourcePort,
              hintText: localizations.routingRulePagePortExample,
            ),
          ],
        ),
        if (AppPlatform.isWindows || AppPlatform.isLinux)
          _textListSection(
            context: context,
            title: localizations.routingRulePageProcess,
            hintText: localizations.routingRulePageProcessExample,
            controllers: controller.processControllers,
            onAdd: controller.appendProcess,
            onDelete: (index) => controller.deleteProcess(context, index),
          ),
      ],
    );
  }

  Widget _inboundSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRulePageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        SettingSection(
          title: localizations.routingRulePageSectionInput,
          separated: false,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SettingsChoiceChips<String>(
                  options: state.inboundTags,
                  selected: state.ruleState.inboundTag.toSet(),
                  labelBuilder: (value) => value,
                  onToggle: (value) => controller.updateInboundTag(
                    !state.ruleState.inboundTag.contains(value),
                    value,
                  ),
                ),
              ),
            ),
          ],
        ),
        _textListSection(
          context: context,
          title: localizations.routingRulePageLocalIP,
          hintText: localizations.routingRulePageIpExample,
          controllers: controller.localIPControllers,
          onAdd: controller.appendLocalIP,
          onDelete: (index) => controller.deleteLocalIP(context, index),
        ),
        SettingSection(
          title: localizations.routingRulePageSectionLocalIP,
          children: [
            TextFieldSettingRow(
              controller: controller.localPortController,
              label: localizations.routingRulePageLocalPort,
              hintText: localizations.routingRulePagePortExample,
            ),
          ],
        ),
      ],
    );
  }

  Widget _trafficSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRulePageState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        SettingSection(
          title: localizations.routingRulePageProtocol,
          children: [
            SelectSettingRow<String>(
              leading: const Icon(LucideIcons.network),
              title: localizations.routingRulePageNetwork,
              value: state.ruleState.network.name,
              selections: RoutingRuleNetwork.names,
              onSelected: controller.updateNetwork,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SettingsChoiceChips<RoutingRuleProtocol>(
                  options: RoutingRuleProtocol.values,
                  selected: state.ruleState.protocol.toSet(),
                  labelBuilder: (value) => value.name,
                  onToggle: (value) => controller.updateProtocol(
                    !state.ruleState.protocol.contains(value),
                    value,
                  ),
                ),
              ),
            ),
          ],
        ),
        SettingSection(
          title: localizations.routingRulePageSectionAttr,
          action: IconButton(
            tooltip: localizations.buttonAdd,
            onPressed: controller.appendAttr,
            icon: const Icon(LucideIcons.plus),
          ),
          children: state.ruleAttrs
              .mapIndexed(
                (index, attr) => Column(
                  children: [
                    TextFieldSettingRow(
                      controller: attr.key,
                      label: localizations.routingRulePageAttrsKey,
                      hintText: localizations.routingRulePageAttrsKey,
                    ),
                    TextFieldActionSettingRow(
                      controller: attr.value,
                      label: localizations.routingRulePageAttrsValue,
                      hintText: localizations.routingRulePageAttrsValue,
                      trailing: IconButton(
                        tooltip: localizations.menuDelete,
                        onPressed: () => controller.deleteAttr(index),
                        icon: const Icon(LucideIcons.trash2),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _textListSection({
    required BuildContext context,
    required String title,
    required String hintText,
    required List<TextEditingController> controllers,
    required VoidCallback onAdd,
    required ValueChanged<int> onDelete,
    VoidCallback? onImport,
  }) {
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: title,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: localizations.buttonAdd,
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus),
          ),
          if (onImport != null)
            IconButton(
              tooltip: localizations.buttonImport,
              onPressed: onImport,
              icon: const Icon(LucideIcons.listFilter),
            ),
        ],
      ),
      children: controllers
          .mapIndexed(
            (index, textController) => TextFieldActionSettingRow(
              controller: textController,
              label: title,
              showLabel: false,
              hintText: hintText,
              trailing: IconButton(
                tooltip: localizations.menuDelete,
                onPressed: () => onDelete(index),
                icon: const Icon(LucideIcons.trash2),
              ),
            ),
          )
          .toList(),
    );
  }
}
