import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule/controller.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/xray/setting/routing_rule_state.dart';

class RoutingRulePage extends StatelessWidget {
  final RoutingRuleParams params;

  const RoutingRulePage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoutingRuleController(params),
      child: BlocBuilder<RoutingRuleController, RoutingRuleCubitState>(
        builder: (context, state) {
          final controller = context.read<RoutingRuleController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.routingRulePageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _domainSection(context, controller, state),
                  _ipSection(context, controller, state),
                  _portSection(context, controller, state),
                  _sourceIPSection(context, controller, state),
                  _localIPSection(context, controller, state),
                  if (AppPlatform.isWindows || AppPlatform.isLinux)
                    _processSection(context, controller, state),
                  _protocolSection(context, controller, state),
                  _attrSection(context, controller, state),
                  _tagSection(context, controller, state),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _domainSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    final title = AppLocalizations.of(context)!.routingRulePageDomain;
    final domainViews = state.ruleState.domain
        .mapIndexed(
          (index, host) => TextFieldActionSettingRow(
            controller: controller.domainControllers[index],
            label: title,
            hintText: AppLocalizations.of(
              context,
            )!.routingRulePageDomainExample,
            trailing: IconButton(
              onPressed: () => controller.deleteDomain(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: title,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => controller.appendDomain(),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                onPressed: () => controller.importDomain(context),
                icon: const Icon(Icons.list),
              ),
            ],
          ),
        ),
        ...domainViews,
      ],
    );
  }

  Widget _ipSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    final title = AppLocalizations.of(context)!.routingRulePageIp;
    final ipViews = state.ruleState.ip
        .mapIndexed(
          (index, host) => TextFieldActionSettingRow(
            controller: controller.ipControllers[index],
            label: title,
            hintText: AppLocalizations.of(context)!.routingRulePageIpExample,
            trailing: IconButton(
              onPressed: () => controller.deleteIp(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: title,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => controller.appendIp(),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                onPressed: () => controller.importIp(context),
                icon: const Icon(Icons.list),
              ),
            ],
          ),
        ),
        ...ipViews,
      ],
    );
  }

  Widget _portSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        _port(context, controller),
        _sourcePort(context, controller),
        _localPort(context, controller),
        _network(context, controller, state),
      ],
    );
  }

  Widget _port(BuildContext context, RoutingRuleController controller) {
    return TextFieldSettingRow(
      controller: controller.portController,
      label: AppLocalizations.of(context)!.routingRulePagePort,
      hintText: AppLocalizations.of(context)!.routingRulePagePortExample,
    );
  }

  Widget _sourcePort(BuildContext context, RoutingRuleController controller) {
    return TextFieldSettingRow(
      controller: controller.sourcePortController,
      label: AppLocalizations.of(context)!.routingRulePageSourcePort,
      hintText: AppLocalizations.of(context)!.routingRulePagePortExample,
    );
  }

  Widget _localPort(BuildContext context, RoutingRuleController controller) {
    return TextFieldSettingRow(
      controller: controller.localPortController,
      label: AppLocalizations.of(context)!.routingRulePageLocalPort,
      hintText: AppLocalizations.of(context)!.routingRulePagePortExample,
    );
  }

  Widget _network(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.routingRulePageNetwork,
      value: state.ruleState.network.name,
      selections: RoutingRuleNetwork.names,
      onSelected: (value) => controller.updateNetwork(value),
    );
  }

  Widget _sourceIPSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    final title = AppLocalizations.of(context)!.routingRulePageSourceIP;
    final sourceViews = state.ruleState.sourceIP
        .mapIndexed(
          (index, path) => TextFieldActionSettingRow(
            controller: controller.sourceIPControllers[index],
            label: title,
            hintText: AppLocalizations.of(context)!.routingRulePageIpExample,
            trailing: IconButton(
              onPressed: () => controller.deleteSourceIP(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: title,
          trailing: IconButton(
            onPressed: () => controller.appendSourceIP(),
            icon: const Icon(Icons.add),
          ),
        ),
        ...sourceViews,
      ],
    );
  }

  Widget _localIPSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    final title = AppLocalizations.of(context)!.routingRulePageLocalIP;
    final sourceViews = state.ruleState.localIP
        .mapIndexed(
          (index, path) => TextFieldActionSettingRow(
            controller: controller.localIPControllers[index],
            label: title,
            hintText: AppLocalizations.of(context)!.routingRulePageIpExample,
            trailing: IconButton(
              onPressed: () => controller.deleteLocalIP(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: title,
          trailing: IconButton(
            onPressed: () => controller.appendLocalIP(),
            icon: const Icon(Icons.add),
          ),
        ),
        ...sourceViews,
      ],
    );
  }

  Widget _protocolSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.routingRulePageProtocol,
      separated: false,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _protocol(context, controller, state),
          ),
        ),
      ],
    );
  }

  Widget _processSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    final title = AppLocalizations.of(context)!.routingRulePageProcess;
    final processViews = state.ruleState.process
        .mapIndexed(
          (index, process) => TextFieldActionSettingRow(
            controller: controller.processControllers[index],
            label: title,
            hintText: AppLocalizations.of(
              context,
            )!.routingRulePageProcessExample,
            trailing: IconButton(
              onPressed: () => controller.deleteProcess(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: title,
          trailing: IconButton(
            onPressed: () => controller.appendProcess(),
            icon: const Icon(Icons.add),
          ),
        ),
        ...processViews,
      ],
    );
  }

  Widget _protocol(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return Wrap(
      spacing: 5.0,
      runSpacing: 5.0,
      children: RoutingRuleProtocol.values
          .map(
            (RoutingRuleProtocol value) => FilterChip(
              label: Text(value.name),
              selected: state.ruleState.protocol.contains(value),
              onSelected: (bool selected) =>
                  controller.updateProtocol(selected, value),
            ),
          )
          .toList(),
    );
  }

  Widget _attrSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    final attrViews = <Widget>[];
    for (final attr in state.ruleAttrs) {
      final key = TextFieldSettingRow(
        controller: attr.key,
        label: AppLocalizations.of(context)!.routingRulePageAttrsKey,
        hintText: AppLocalizations.of(context)!.routingRulePageAttrsKey,
      );
      final value = TextFieldSettingRow(
        controller: attr.value,
        label: AppLocalizations.of(context)!.routingRulePageAttrsValue,
        hintText: AppLocalizations.of(context)!.routingRulePageAttrsValue,
      );
      attrViews.add(key);
      attrViews.add(value);
    }
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.routingRulePageAttrs,
          trailing: IconButton(
            onPressed: () => controller.appendAttr(),
            icon: const Icon(Icons.add),
          ),
        ),
        ...attrViews,
      ],
    );
  }

  Widget _tagSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        _outboundTag(context, controller, state),
        _ruleTag(context, controller),
      ],
    );
  }

  Widget _outboundTag(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.routingRulePageOutboundTag,
      value: state.ruleState.outboundTag,
      selections: state.outboundTags,
      onSelected: (value) => controller.updateOutboundTag(value),
    );
  }

  Widget _ruleTag(BuildContext context, RoutingRuleController controller) {
    return TextFieldSettingRow(
      controller: controller.ruleTagController,
      label: AppLocalizations.of(context)!.routingRulePageRuleTag,
      hintText: AppLocalizations.of(context)!.routingRulePageRuleTag,
    );
  }

  Widget _bottomButton(BuildContext context, RoutingRuleController controller) {
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
