import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_out/controller.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_out/params.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/text_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoutingRuleDnsOutPage extends StatelessWidget {
  final RoutingRuleDnsOutParams params;

  const RoutingRuleDnsOutPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoutingRuleDnsOutController(params),
      child: BlocBuilder<RoutingRuleDnsOutController, RoutingRuleDnsOutCubitState>(
        builder: (context, state) {
          final controller = context.read<RoutingRuleDnsOutController>();
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

  Widget _body(BuildContext context, RoutingRuleDnsOutController controller, RoutingRuleDnsOutCubitState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inboundTagSection(context, controller, state),
            _portSection(context, controller, state),
            _tagSection(context, controller, state),
          ],
        ),
      ),
    );
  }

  Widget _inboundTagSection(
    BuildContext context,
    RoutingRuleDnsOutController controller, RoutingRuleDnsOutCubitState state) {
    final views = state.ruleState.inboundTag
        .map((e) => Text(e))
        .toList();
    return SectionView(
      title: AppLocalizations.of(context)!.routingRulePageInboundTag,
      child: Column(children: views),
    );
  }

  Widget _portSection(
    BuildContext context,
    RoutingRuleDnsOutController controller, RoutingRuleDnsOutCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.routingRulePagePort,
            detail: state.ruleState.port,
          ),
        ],
      ),
    );
  }

  Widget _tagSection(
    BuildContext context,
    RoutingRuleDnsOutController controller, RoutingRuleDnsOutCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.routingRulePageOutboundTag,
            detail: state.ruleState.outboundTag,
          ),
          TextRow(
            title: AppLocalizations.of(context)!.routingRulePageRuleTag,
            detail: state.ruleState.ruleTag,
          ),
        ],
      ),
    );
  }
}
