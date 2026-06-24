import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/xray/setting/routing_rule_dns_dot/controller.dart';
import 'package:onexray/pages/core/xray/setting/routing_rule_dns_dot/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RoutingRuleDnsDoTPage extends StatelessWidget {
  final RoutingRuleDnsDoTParams params;

  const RoutingRuleDnsDoTPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoutingRuleDnsDoTController(params),
      child:
          BlocBuilder<RoutingRuleDnsDoTController, RoutingRuleDnsDoTCubitState>(
            builder: (context, state) {
              final controller = context.read<RoutingRuleDnsDoTController>();
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    AppLocalizations.of(context)!.routingRulePageTitle,
                  ),
                ),
                body: SafeArea(child: _body(context, controller, state)),
              );
            },
          ),
    );
  }

  Widget _body(
    BuildContext context,
    RoutingRuleDnsDoTController controller,
    RoutingRuleDnsDoTCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
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
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _inboundTagSection(
    BuildContext context,
    RoutingRuleDnsDoTController controller,
    RoutingRuleDnsDoTCubitState state,
  ) {
    final views = state.ruleState.inboundTag
        .map((tag) => SettingRow(title: tag))
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.routingRulePageInboundTag,
      children: views,
    );
  }

  Widget _portSection(
    BuildContext context,
    RoutingRuleDnsDoTController controller,
    RoutingRuleDnsDoTCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.routingRulePagePort,
          value: state.ruleState.port,
        ),
      ],
    );
  }

  Widget _tagSection(
    BuildContext context,
    RoutingRuleDnsDoTController controller,
    RoutingRuleDnsDoTCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        _outboundTag(context, controller, state),
        _ruleTag(context, controller, state),
      ],
    );
  }

  Widget _outboundTag(
    BuildContext context,
    RoutingRuleDnsDoTController controller,
    RoutingRuleDnsDoTCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.routingRulePageOutboundTag,
      value: state.ruleState.outboundTag,
      selections: state.outboundTags,
      onSelected: (value) => controller.updateOutboundTag(value),
    );
  }

  Widget _ruleTag(
    BuildContext context,
    RoutingRuleDnsDoTController controller,
    RoutingRuleDnsDoTCubitState state,
  ) {
    return SettingRow(
      title: AppLocalizations.of(context)!.routingRulePageRuleTag,
      value: state.ruleState.ruleTag,
    );
  }

  Widget _bottomButton(
    BuildContext context,
    RoutingRuleDnsDoTController controller,
  ) {
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
