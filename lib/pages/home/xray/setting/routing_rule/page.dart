import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule/controller.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
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
    final domainViews = state.ruleState.domain
        .mapIndexed(
          (index, host) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.domainControllers[index],
                  decoration: InputDecoration(
                    label: Text(
                      AppLocalizations.of(context)!.routingRulePageDomain,
                    ),
                    hintText: AppLocalizations.of(
                      context,
                    )!.routingRulePageDomainExample,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.deleteDomain(context, index),
                icon: Icon(Icons.delete),
              ),
            ],
          ),
        )
        .toList();
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            children: [
              Text(AppLocalizations.of(context)!.routingRulePageDomain),
              const Spacer(),
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
          if (domainViews.isNotEmpty) Column(children: domainViews),
        ],
      ),
    );
  }

  Widget _ipSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    final ipViews = state.ruleState.ip
        .mapIndexed(
          (index, host) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.ipControllers[index],
                  decoration: InputDecoration(
                    label: Text(
                      AppLocalizations.of(context)!.routingRulePageIp,
                    ),
                    hintText: AppLocalizations.of(
                      context,
                    )!.routingRulePageIpExample,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.deleteIp(context, index),
                icon: Icon(Icons.delete),
              ),
            ],
          ),
        )
        .toList();
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            children: [
              Text(AppLocalizations.of(context)!.routingRulePageIp),
              const Spacer(),
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
          if (ipViews.isNotEmpty) Column(children: ipViews),
        ],
      ),
    );
  }

  Widget _portSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          _port(context, controller),
          _sourcePort(context, controller),
          _localPort(context, controller),
          _network(context, controller, state),
        ],
      ),
    );
  }

  Widget _port(BuildContext context, RoutingRuleController controller) {
    return TextField(
      controller: controller.portController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.routingRulePagePort),
        hintText: AppLocalizations.of(context)!.routingRulePagePortExample,
      ),
    );
  }

  Widget _sourcePort(BuildContext context, RoutingRuleController controller) {
    return TextField(
      controller: controller.sourcePortController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.routingRulePageSourcePort),
        hintText: AppLocalizations.of(context)!.routingRulePagePortExample,
      ),
    );
  }

  Widget _localPort(BuildContext context, RoutingRuleController controller) {
    return TextField(
      controller: controller.localPortController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.routingRulePageLocalPort),
        hintText: AppLocalizations.of(context)!.routingRulePagePortExample,
      ),
    );
  }

  Widget _network(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.routingRulePageNetwork),
        TextMenuPicker(
          title: state.ruleState.network.name,
          selections: RoutingRuleNetwork.names,
          callback: (value) => controller.updateNetwork(value),
        ),
      ],
    );
  }

  Widget _sourceIPSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    final sourceViews = state.ruleState.sourceIP
        .mapIndexed(
          (index, path) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.sourceIPControllers[index],
                  decoration: InputDecoration(
                    label: Text(
                      AppLocalizations.of(context)!.routingRulePageSourceIP,
                    ),
                    hintText: AppLocalizations.of(
                      context,
                    )!.routingRulePageIpExample,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.deleteSourceIP(context, index),
                icon: Icon(Icons.delete),
              ),
            ],
          ),
        )
        .toList();
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.routingRulePageSourceIP),
              IconButton(
                onPressed: () => controller.appendSourceIP(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (sourceViews.isNotEmpty) Column(children: sourceViews),
        ],
      ),
    );
  }

  Widget _localIPSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    final sourceViews = state.ruleState.localIP
        .mapIndexed(
          (index, path) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.localIPControllers[index],
                  decoration: InputDecoration(
                    label: Text(
                      AppLocalizations.of(context)!.routingRulePageLocalIP,
                    ),
                    hintText: AppLocalizations.of(
                      context,
                    )!.routingRulePageIpExample,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.deleteLocalIP(context, index),
                icon: Icon(Icons.delete),
              ),
            ],
          ),
        )
        .toList();
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.routingRulePageLocalIP),
              IconButton(
                onPressed: () => controller.appendLocalIP(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (sourceViews.isNotEmpty) Column(children: sourceViews),
        ],
      ),
    );
  }

  Widget _protocolSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return SectionView(
      title: AppLocalizations.of(context)!.routingRulePageProtocol,
      child: _protocol(context, controller, state),
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
      final key = TextField(
        controller: attr.key,
        decoration: InputDecoration(
          label: Text(AppLocalizations.of(context)!.routingRulePageAttrsKey),
          hintText: AppLocalizations.of(context)!.routingRulePageAttrsKey,
        ),
      );
      final value = TextField(
        controller: attr.value,
        decoration: InputDecoration(
          label: Text(AppLocalizations.of(context)!.routingRulePageAttrsValue),
          hintText: AppLocalizations.of(context)!.routingRulePageAttrsValue,
        ),
      );
      attrViews.add(key);
      attrViews.add(value);
    }
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.routingRulePageAttrs),
              IconButton(
                onPressed: () => controller.appendAttr(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (attrViews.isNotEmpty) Column(children: attrViews),
        ],
      ),
    );
  }

  Widget _tagSection(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          _outboundTag(context, controller, state),
          _ruleTag(context, controller),
        ],
      ),
    );
  }

  Widget _outboundTag(
    BuildContext context,
    RoutingRuleController controller,
    RoutingRuleCubitState state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.routingRulePageOutboundTag),
        TextMenuPicker(
          title: state.ruleState.outboundTag,
          selections: state.outboundTags,
          callback: (value) => controller.updateOutboundTag(value),
        ),
      ],
    );
  }

  Widget _ruleTag(BuildContext context, RoutingRuleController controller) {
    return TextField(
      controller: controller.ruleTagController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.routingRulePageRuleTag),
        hintText: AppLocalizations.of(context)!.routingRulePageRuleTag,
      ),
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
