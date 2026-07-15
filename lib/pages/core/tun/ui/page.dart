import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/tun/ui/controller.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/tun_settings/enum.dart';
import 'package:onexray/service/tun_settings/state.dart';

class TunSettingsPage extends StatelessWidget {
  const TunSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TunSettingsContent();
  }
}

class TunSettingsContent extends StatelessWidget {
  const TunSettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TunSettingsController(),
      child: BlocBuilder<TunSettingsController, TunSettingsPageState>(
        builder: (context, state) {
          final controller = context.read<TunSettingsController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.tunSettingsPageTitle,
            onSave: () => controller.save(context),
            body: _body(context, state, controller),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingsPageIntro(
            title: AppLocalizations.of(context)!.tunSettingsPageTitle,
          ),
          SettingsResponsiveColumns(
            firstFlex: 5,
            secondFlex: 5,
            first: [
              _dnsSection(context, controller),
              _runtimeSection(context, state, controller),
            ],
            second: _platformSections(context, state, controller),
          ),
        ],
      ),
    );
  }

  List<Widget> _platformSections(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    if (AppPlatform.isIOS || AppPlatform.isMacOS) {
      return [
        _dotSection(context, state, controller),
        _onDemandSection(context, state, controller),
      ];
    }
    if (AppPlatform.isAndroid) {
      return [_perAppVPNSection(context, state, controller)];
    }
    if (AppPlatform.isLinux || AppPlatform.isWindows) {
      return [_interfaceSection(context, state, controller)];
    }
    return const [];
  }

  Widget _dnsSection(BuildContext context, TunSettingsController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageDns,
      children: [
        _tunDnsIPv4(context, controller),
        _tunDnsIPv6(context, controller),
      ],
    );
  }

  Widget _runtimeSection(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.settingsPageSectionNetwork,
      children: [
        _enableIPv6(context, state, controller),
        _metricsEnabled(context, state, controller),
      ],
    );
  }

  Widget _dotSection(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.tunSettingsPageTunDnsEnableDot,
      children: [
        _enableDot(context, state, controller),
        if (state.tunSettings.enableDot) _tunDnsServerName(context, controller),
      ],
    );
  }

  Widget _tunDnsIPv4(BuildContext context, TunSettingsController controller) {
    return TextFieldSettingRow(
      controller: controller.tunDnsIPv4Controller,
      label: AppLocalizations.of(context)!.tunSettingsPageTunDnsIPv4,
      hintText: AppLocalizations.of(context)!.tunSettingsPageTunDnsIPv4Example,
    );
  }

  Widget _tunDnsIPv6(BuildContext context, TunSettingsController controller) {
    return TextFieldSettingRow(
      controller: controller.tunDnsIPv6Controller,
      label: AppLocalizations.of(context)!.tunSettingsPageTunDnsIPv6,
      hintText: AppLocalizations.of(context)!.tunSettingsPageTunDnsIPv6Example,
    );
  }

  Widget _enableDot(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SwitchSettingRow(
      leading: const Icon(LucideIcons.lockKeyhole),
      title: AppLocalizations.of(context)!.tunSettingsPageTunDnsEnableDot,
      value: state.tunSettings.enableDot,
      onChanged: (value) => controller.updateEnableDot(value),
    );
  }

  Widget _tunDnsServerName(
    BuildContext context,
    TunSettingsController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.tunDnsServerNameController,
      label: AppLocalizations.of(context)!.tunSettingsPageTunDnsServerName,
      hintText: AppLocalizations.of(
        context,
      )!.tunSettingsPageTunDnsServerNameExample,
    );
  }

  Widget _enableIPv6(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SwitchSettingRow(
      leading: const Icon(LucideIcons.globe2),
      title: AppLocalizations.of(context)!.tunSettingsPageEnableIPv6,
      subtitle: AppLocalizations.of(context)!.tunSettingsPageEnableIPv6Tip,
      value: state.tunSettings.enableIPv6,
      onChanged: (value) => controller.updateEnableIPv6(value),
    );
  }

  Widget _metricsEnabled(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SwitchSettingRow(
      leading: const Icon(LucideIcons.activity),
      title: AppLocalizations.of(context)!.tunSettingsPageMetrics,
      value: state.tunSettings.metricsEnabled,
      onChanged: (value) => controller.updateMetricsEnabled(value),
    );
  }

  Widget _interfaceSection(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.tunSettingsPageInterface,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.radioTower),
          title: AppLocalizations.of(context)!.tunSettingsPageTunName,
          value: state.tunSettings.tunName,
          enabled: false,
        ),
        _interface(context, state, controller),
      ],
    );
  }

  Widget _interface(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return NavigationSettingRow(
      leading: const Icon(LucideIcons.network),
      title: AppLocalizations.of(context)!.tunSettingsPageInterface,
      value: state.tunSettings.autoOutboundsInterface,
      onTap: () => controller.editInterface(context),
    );
  }

  Widget _onDemandSection(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.tunSettingsPageOnDemandEnabled,
      children: [
        _onDemandEnabled(context, state, controller),
        if (state.tunSettings.onDemandEnabled)
          ..._onDemandRulesSection(context, state, controller),
      ],
    );
  }

  Widget _onDemandEnabled(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SwitchSettingRow(
      leading: const Icon(LucideIcons.zap),
      title: AppLocalizations.of(context)!.tunSettingsPageOnDemandEnabled,
      value: state.tunSettings.onDemandEnabled,
      onChanged: (value) => controller.updateOnDemandEnabled(value),
    );
  }

  List<Widget> _onDemandRulesSection(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    final ruleViews = state.tunSettings.onDemandRules
        .mapIndexed(
          (index, rule) => _onDemandRuleCell(context, controller, rule, index),
        )
        .toList();
    return [
      SettingRow(
        leading: const Icon(LucideIcons.listOrdered),
        title: AppLocalizations.of(context)!.tunSettingsPageOnDemandRules,
        subtitle: AppLocalizations.of(context)!.helpOrder,
        trailing: IconButton(
          onPressed: () => controller.appendOnDemandRule(),
          icon: const Icon(LucideIcons.plus),
        ),
      ),
      if (ruleViews.isNotEmpty)
        ReorderableListView(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          onReorderItem: controller.sortOnDemandRule,
          children: ruleViews,
        ),
    ];
  }

  Widget _onDemandRuleCell(
    BuildContext context,
    TunSettingsController controller,
    OnDemandRuleState rule,
    int index,
  ) {
    return ReorderableDelayedDragStartListener(
      key: Key("$index"),
      index: index,
      child: DataListRow(
        onTap: () => controller.editOnDemandRule(context, index),
        title: rule.interfaceType.name,
        tags: [TagView(tag: rule.mode.name)],
        trailing: ActionCluster(
          children: [
            AppMenuButton<IconMenuId>(
              icon: LucideIcons.ellipsis,
              entries: iconMenuEntries([IconMenuId.delete]),
              onSelected: (menuId) => controller.moreAction(menuId, index),
            ),
            ReorderDragHandle(
              index: index,
              tooltip: AppLocalizations.of(context)!.helpOrder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _perAppVPNSection(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.tunSettingsPagePerAppVPN,
      children: [
        _perAppVPNMode(context, state, controller),
        _appList(context, state, controller),
      ],
    );
  }

  Widget _perAppVPNMode(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    return SelectSettingRow(
      leading: const Icon(LucideIcons.smartphone),
      title: AppLocalizations.of(context)!.tunSettingsPagePerAppVPNMode,
      value: state.tunSettings.perAppVPNMode.name,
      selections: PerAppVPNMode.names,
      onSelected: (value) => controller.updatePerAppVPNMode(value),
    );
  }

  Widget _appList(
    BuildContext context,
    TunSettingsPageState state,
    TunSettingsController controller,
  ) {
    var length = 0;
    switch (state.tunSettings.perAppVPNMode) {
      case PerAppVPNMode.allow:
        length = state.tunSettings.allowAppList.length;
        break;
      case PerAppVPNMode.disallow:
        length = state.tunSettings.disallowAppList.length;
        break;
    }
    return NavigationSettingRow(
      leading: const Icon(LucideIcons.appWindow),
      title: AppLocalizations.of(context)!.tunSettingsPagePerAppVPN,
      value: AppLocalizations.of(
        context,
      )!.tunSettingsPagePerAppVPNCount("$length"),
      subtitle: AppLocalizations.of(context)!.tunSettingsPagePerAppVPNHelp,
      onTap: () => controller.editAppList(context),
    );
  }
}
