import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/controller.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/xray/setting/enum.dart';

class OutboundDnsPage extends StatelessWidget {
  final OutboundDnsParams params;

  const OutboundDnsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundDnsController(params),
      child: BlocBuilder<OutboundDnsController, OutboundDnsCubitState>(
        builder: (context, state) {
          final controller = context.read<OutboundDnsController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.outboundDnsPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ResponsiveContent(
                child: Column(
                  children: [
                    _protocolSection(context, controller, state),
                    _settingSection(context, controller, state),
                    _rulesSection(context, controller, state),
                    _blockTypesSection(context, controller),
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

  Widget _protocolSection(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.outboundDnsPageProtocol,
          value: state.dnsState.protocol.name,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.outboundDnsPageTag,
          value: state.dnsState.tag.name,
        ),
      ],
    );
  }

  Widget _settingSection(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
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
    OutboundDnsCubitState state,
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
    OutboundDnsCubitState state,
  ) {
    final views = state.dnsState.rules
        .mapIndexed(
          (index, rule) => _ruleCell(context, controller, state, index),
        )
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundDnsPageRules,
      separated: false,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.outboundDnsPageRules,
          trailing: IconButton(
            onPressed: () => controller.appendRule(),
            icon: const Icon(Icons.add),
          ),
        ),
        if (views.isNotEmpty)
          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            onReorderItem: (oldIndex, newIndex) => controller.sortRule(
              oldIndex,
              _legacyReorderNewIndex(oldIndex, newIndex),
            ),
            children: views,
          ),
      ],
    );
  }

  Widget _ruleCell(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
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
                  onPressed: () => controller.deleteRule(ruleIndex),
                  icon: const Icon(Icons.delete),
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

  Widget _blockTypesSection(
    BuildContext context,
    OutboundDnsController controller,
  ) {
    final views = controller.blockTypeControllers
        .mapIndexed(
          (index, itemController) => TextFieldActionSettingRow(
            controller: itemController,
            label: AppLocalizations.of(context)!.outboundDnsPageBlockType,
            hintText: AppLocalizations.of(
              context,
            )!.outboundDnsPageBlockTypeExample,
            keyboardType: TextInputType.number,
            trailing: IconButton(
              onPressed: () => controller.deleteBlockType(index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundDnsPageBlockTypes,
      separated: false,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.outboundDnsPageBlockTypes,
          subtitle: AppLocalizations.of(context)!.outboundDnsPageBlockTypesHint,
          trailing: IconButton(
            onPressed: () => controller.appendBlockType(),
            icon: const Icon(Icons.add),
          ),
        ),
        if (views.isNotEmpty) Column(children: views),
      ],
    );
  }

  Widget _bottomButton(BuildContext context, OutboundDnsController controller) {
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

  int _legacyReorderNewIndex(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      return newIndex + 1;
    }
    return newIndex;
  }
}
