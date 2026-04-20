import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/routing/controller.dart';
import 'package:onexray/pages/home/xray/setting/routing/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/routing_rule_state.dart';

class RoutingPage extends StatelessWidget {
  final RoutingParams params;

  const RoutingPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RoutingController(params),
      child: BlocBuilder<RoutingController, RoutingCubitState>(
        builder: (context, state) {
          final controller = context.read<RoutingController>();
          return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.routingPageTitle),
        ),
        body: SafeArea(child: _body(context, controller, state)),
      );
        },
      ),
    );
  }

  Widget _body(BuildContext context, RoutingController controller, RoutingCubitState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _routingSection(context, controller, state),
                  _ruleSection(context, controller, state),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _routingSection(BuildContext context, RoutingController controller, RoutingCubitState state) {
    return SectionView(
      title: "",
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(AppLocalizations.of(context)!.routingPageDomainStrategy),
          TextMenuPicker(
            title: state.routingState.domainStrategy.name,
            selections: RoutingDomainStrategy.names,
            callback: (value) => controller.updateDomainStrategy(value),
          ),
        ],
      ),
    );
  }

  Widget _ruleSection(BuildContext context, RoutingController controller, RoutingCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.routingPageRules),
              IconButton(
                onPressed: () => controller.appendCustomRule(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          _systemRuleSection(context, controller, state),
          if (state.routingState.customRules.isNotEmpty)
            _customRuleSection(context, controller, state),
        ],
      ),
    );
  }

  Widget _systemRuleSection(
    BuildContext context,
    RoutingController controller, RoutingCubitState state) {
    final rules = <RoutingRuleState>[
      state.routingState.dnsQueryRule,
      state.routingState.dnsOutRule,
      state.routingState.dnsDoTRule,
    ];
    final ruleViews = rules
        .mapIndexed(
          (index, rule) => _systemRuleCell(context, controller, rule, index),
        )
        .toList();
    return SectionView(
      title: "",
      level: SectionLevel.second,
      child: Column(children: ruleViews),
    );
  }

  Widget _systemRuleCell(
    BuildContext context,
    RoutingController controller,
    RoutingRuleState rule,
    int ruleIndex,
  ) {
    return ListTile(
      onTap: () => controller.showSystemRule(context, ruleIndex),
      title: Text(rule.ruleTag),
      subtitle: Row(children: [TagView(tag: rule.uiTag)]),
    );
  }

  Widget _customRuleSection(
    BuildContext context,
    RoutingController controller, RoutingCubitState state) {
    final ruleViews = state.routingState.customRules
        .mapIndexed(
          (index, rule) => _customRuleCell(context, controller, rule, index),
        )
        .toList();
    return SectionView(
      title: AppLocalizations.of(context)!.helpOrder,
      level: SectionLevel.second,
      child: ReorderableListView(
        shrinkWrap: true,
        onReorder: (int oldIndex, int newIndex) =>
            controller.sortCustomRule(oldIndex, newIndex),
        children: ruleViews,
      ),
    );
  }

  Widget _customRuleCell(
    BuildContext context,
    RoutingController controller,
    RoutingRuleState rule,
    int ruleIndex,
  ) {
    var contentPadding = EdgeInsetsDirectional.symmetric(horizontal: 16);
    if (AppPlatform.isDesktop) {
      contentPadding = EdgeInsetsDirectional.only(start: 16, end: 40);
    }
    return ListTile(
      key: Key("$ruleIndex"),
      contentPadding: contentPadding,
      onTap: () => controller.editCustomRule(context, ruleIndex),
      title: Text(rule.ruleTag),
      subtitle: Row(children: [TagView(tag: rule.uiTag)]),
      trailing: IconMenuPicker(
        icon: Icons.more_vert,
        menus: [IconMenuId.delete],
        callback: (menuId) => controller.ruleMoreAction(menuId, ruleIndex),
      ),
    );
  }

  Widget _bottomButton(BuildContext context, RoutingController controller) {
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
