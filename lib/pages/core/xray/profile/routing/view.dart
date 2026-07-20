import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/routing_rule_state.dart';
import 'package:onexray/service/xray/profile/routing_state.dart';

class RoutingView extends StatelessWidget {
  final RoutingState state;
  final ValueChanged<String> onUpdateDomainStrategy;
  final ValueChanged<int> onShowSystemRule;
  final VoidCallback onAppendCustomRule;
  final ReorderCallback onSortCustomRule;
  final ValueChanged<int> onEditCustomRule;
  final ValueChanged<int> onDeleteCustomRule;

  const RoutingView({
    super.key,
    required this.state,
    required this.onUpdateDomainStrategy,
    required this.onShowSystemRule,
    required this.onAppendCustomRule,
    required this.onSortCustomRule,
    required this.onEditCustomRule,
    required this.onDeleteCustomRule,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingsPageIntro(title: l10n.routingPageTitle),
          SettingsResponsiveColumns(
            firstFlex: 4,
            secondFlex: 6,
            first: [_routingSection(context), _systemRuleSection(context)],
            second: [_customRuleSection(context)],
          ),
        ],
      ),
    );
  }

  Widget _routingSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.routingPageSectionStrategy,
      children: [
        SelectSettingRow(
          leading: const Icon(LucideIcons.route),
          title: l10n.routingPageDomainStrategy,
          value: state.domainStrategy.name,
          selections: RoutingDomainStrategy.names,
          onSelected: onUpdateDomainStrategy,
        ),
      ],
    );
  }

  Widget _systemRuleSection(BuildContext context) {
    final rules = <RoutingRuleState>[
      state.dnsQueryRule,
      state.dnsOutRule,
      state.dnsDoTRule,
    ];
    return SettingSection(
      title: AppLocalizations.of(context)!.routingPageSectionSystemRules,
      children: rules
          .mapIndexed((index, rule) => _systemRuleCell(rule, index))
          .toList(),
    );
  }

  Widget _systemRuleCell(RoutingRuleState rule, int ruleIndex) {
    return NavigationSettingRow(
      leading: const Icon(LucideIcons.shieldCheck),
      onTap: () => onShowSystemRule(ruleIndex),
      title: rule.ruleTag,
      subtitleWidget: Row(children: [TagView(tag: rule.uiTag)]),
    );
  }

  Widget _customRuleSection(BuildContext context) {
    final ruleViews = state.customRules
        .mapIndexed((index, rule) => _customRuleCell(context, rule, index))
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.routingPageSectionCustomRules,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.listFilter),
          title: AppLocalizations.of(context)!.routingPageRules,
          trailing: IconButton(
            onPressed: onAppendCustomRule,
            icon: const Icon(LucideIcons.plus),
          ),
        ),
        if (ruleViews.isNotEmpty)
          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: onSortCustomRule,
            children: ruleViews,
          ),
      ],
    );
  }

  Widget _customRuleCell(
    BuildContext context,
    RoutingRuleState rule,
    int ruleIndex,
  ) {
    return ReorderableDelayedDragStartListener(
      key: Key("$ruleIndex"),
      index: ruleIndex,
      child: SettingRow(
        onTap: () => onEditCustomRule(ruleIndex),
        title: rule.ruleTag,
        subtitleWidget: Row(children: [TagView(tag: rule.uiTag)]),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppMenuButton<IconMenuId>(
              icon: LucideIcons.ellipsis,
              entries: iconMenuEntries([IconMenuId.delete]),
              onSelected: (_) => onDeleteCustomRule(ruleIndex),
            ),
            ReorderDragHandle(
              index: ruleIndex,
              tooltip: AppLocalizations.of(context)!.helpOrder,
            ),
          ],
        ),
      ),
    );
  }
}
