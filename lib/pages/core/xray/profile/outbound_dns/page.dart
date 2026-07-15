import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/outbound_dns/controller.dart';
import 'package:onexray/pages/core/xray/profile/outbound_dns/params.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class OutboundDnsPage extends StatelessWidget {
  final OutboundDnsParams params;

  const OutboundDnsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundDnsController(params),
      child: BlocBuilder<OutboundDnsController, OutboundDnsPageState>(
        builder: (context, state) {
          final controller = context.read<OutboundDnsController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.outboundDnsPageTitle,
            onSave: () => controller.save(context),
            body: SettingsPageScroll(
              desktopMaxWidth: 980,
              child: SettingsResponsiveColumns(
                firstFlex: 4,
                secondFlex: 6,
                first: [
                  _protocolSection(context, controller, state),
                  _settingSection(context, controller, state),
                  _sockoptSection(context, controller, state),
                ],
                second: [_rulesSection(context, controller, state)],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _protocolSection(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsPageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundDnsPageTitle,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.waypoints),
          title: AppLocalizations.of(context)!.outboundDnsPageProtocol,
          value: state.dnsState.protocol.name,
        ),
        SettingRow(
          leading: const Icon(LucideIcons.tag),
          title: AppLocalizations.of(context)!.outboundDnsPageTag,
          value: state.dnsState.tag.name,
        ),
      ],
    );
  }

  Widget _settingSection(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsPageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundDnsPageSettings,
      children: [
        _network(context, controller, state),
        _address(context, controller),
        _port(context, controller),
      ],
    );
  }

  Widget _network(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsPageState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundDnsPageNetwork,
      value: state.dnsState.network.name,
      selections: DnsNetwork.names,
      onSelected: (value) => controller.updateNetwork(value),
    );
  }

  Widget _address(BuildContext context, OutboundDnsController controller) {
    return TextFieldSettingRow(
      controller: controller.addressController,
      label: AppLocalizations.of(context)!.outboundDnsPageAddress,
      hintText: AppLocalizations.of(context)!.outboundDnsPageAddress,
    );
  }

  Widget _port(BuildContext context, OutboundDnsController controller) {
    return TextFieldSettingRow(
      controller: controller.portController,
      label: AppLocalizations.of(context)!.outboundDnsPagePort,
      hintText: AppLocalizations.of(context)!.outboundDnsPagePort,
    );
  }

  Widget _rulesSection(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsPageState state,
  ) {
    final views = state.dnsState.rules
        .mapIndexed(
          (index, rule) => _ruleCell(context, controller, state, index),
        )
        .toList();
    final localizations = AppLocalizations.of(context)!;
    return SettingSection(
      title: localizations.outboundDnsPageRules,
      action: IconButton(
        tooltip: localizations.buttonAdd,
        onPressed: controller.appendRule,
        icon: const Icon(LucideIcons.plus),
      ),
      separated: false,
      children: [
        if (views.isNotEmpty)
          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            onReorderItem: controller.sortRule,
            children: views,
          ),
      ],
    );
  }

  Widget _ruleCell(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsPageState state,
    int ruleIndex,
  ) {
    final rule = state.dnsState.rules[ruleIndex];
    final action = DnsOutboundRuleAction.fromString(rule.action ?? "");
    return ReorderableDelayedDragStartListener(
      key: Key("rule-$ruleIndex"),
      index: ruleIndex,
      child: SettingSubsection(
        title: "",
        children: [
          SettingRow(
            title:
                "${AppLocalizations.of(context)!.outboundDnsPageRule} ${ruleIndex + 1}",
            trailing: ActionCluster(
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context)!.menuDelete,
                  onPressed: () => controller.deleteRule(ruleIndex),
                  icon: const Icon(LucideIcons.trash2),
                ),
                ReorderDragHandle(
                  index: ruleIndex,
                  tooltip: AppLocalizations.of(context)!.helpOrder,
                ),
              ],
            ),
          ),
          SelectSettingRow(
            title: AppLocalizations.of(context)!.outboundDnsPageRuleAction,
            value: action?.name ?? DnsOutboundRuleAction.direct.name,
            selections: DnsOutboundRuleAction.names,
            onSelected: (value) =>
                controller.updateRuleAction(ruleIndex, value),
          ),
          TextFieldSettingRow(
            controller: controller.ruleQTypeControllers[ruleIndex],
            label: AppLocalizations.of(context)!.outboundDnsPageRuleQType,
            hintText: AppLocalizations.of(
              context,
            )!.outboundDnsPageRuleQTypeExample,
          ),
          TextFieldSettingRow(
            controller: controller.ruleDomainControllers[ruleIndex],
            label: AppLocalizations.of(context)!.outboundDnsPageRuleDomain,
            hintText: AppLocalizations.of(
              context,
            )!.outboundDnsPageRuleDomainExample,
            maxLines: 2,
          ),
          TextFieldSettingRow(
            controller: controller.ruleRCodeControllers[ruleIndex],
            label: AppLocalizations.of(context)!.outboundDnsPageRuleRCode,
            hintText: AppLocalizations.of(
              context,
            )!.outboundDnsPageRuleRCodeExample,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _sockoptSection(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsPageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundDnsPageSockopt,
      children: [
        SelectSettingRow(
          title: AppLocalizations.of(context)!.outboundDnsPageDialerProxy,
          value: state.dnsState.dialerProxy,
          selections: state.outboundTags,
          onSelected: controller.updateDialerProxy,
        ),
      ],
    );
  }
}
