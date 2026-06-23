import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_query/controller.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_query/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class RoutingRuleDnsQueryPage extends StatelessWidget {
  final RoutingRuleDnsQueryParams params;

  const RoutingRuleDnsQueryPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoutingRuleDnsQueryController(params),
      child:
          BlocBuilder<
            RoutingRuleDnsQueryController,
            RoutingRuleDnsQueryCubitState
          >(
            builder: (context, state) {
              final controller = context.read<RoutingRuleDnsQueryController>();
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
    RoutingRuleDnsQueryController controller,
    RoutingRuleDnsQueryCubitState state,
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
    RoutingRuleDnsQueryController controller,
    RoutingRuleDnsQueryCubitState state,
  ) {
    final views = state.ruleState.inboundTag
        .map((tag) => SettingRow(title: tag))
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.routingRulePageInboundTag,
      children: views,
    );
  }

  Widget _tagSection(
    BuildContext context,
    RoutingRuleDnsQueryController controller,
    RoutingRuleDnsQueryCubitState state,
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
    RoutingRuleDnsQueryController controller,
    RoutingRuleDnsQueryCubitState state,
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
    RoutingRuleDnsQueryController controller,
    RoutingRuleDnsQueryCubitState state,
  ) {
    return SettingRow(
      title: AppLocalizations.of(context)!.routingRulePageRuleTag,
      value: state.ruleState.ruleTag,
    );
  }

  Widget _bottomButton(
    BuildContext context,
    RoutingRuleDnsQueryController controller,
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
