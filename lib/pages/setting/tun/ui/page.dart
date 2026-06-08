import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/tun/ui/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/tun_setting/enum.dart';
import 'package:onexray/service/tun_setting/state.dart';

class TunSettingUIPage extends StatelessWidget {
  const TunSettingUIPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TunSettingUIController(),
      child: BlocBuilder<TunSettingUIController, TunSettingUIState>(
        builder: (context, state) {
          final controller = context.read<TunSettingUIController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.tunSettingUIPageTitle),
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: _buildColumnView(context, state, controller),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _buildColumnView(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    if (AppPlatform.isIOS) {
      return _iOSView(context, state, controller);
    }
    if (AppPlatform.isMacOS) {
      return _macOSView(context, state, controller);
    }
    if (AppPlatform.isAndroid) {
      return _androidView(context, state, controller);
    }
    if (AppPlatform.isLinux) {
      return _linuxView(context, state, controller);
    }
    if (AppPlatform.isWindows) {
      return _windowsView(context, state, controller);
    }
    return Container();
  }

  Widget _iOSView(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return Column(
      children: [
        _tunSection(context, state, controller),
        _onDemandSection(context, state, controller),
      ],
    );
  }

  Widget _macOSView(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return Column(
      children: [
        _tunSection(context, state, controller),
        _onDemandSection(context, state, controller),
      ],
    );
  }

  Widget _androidView(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return Column(
      children: [
        _tunSection(context, state, controller),
        _perAppVPNSection(context, state, controller),
      ],
    );
  }

  Widget _linuxView(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return Column(
      children: [
        _tunSection(context, state, controller),
        _interfaceSection(context, state, controller),
      ],
    );
  }

  Widget _windowsView(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return Column(
      children: [
        _tunSection(context, state, controller),
        _interfaceSection(context, state, controller),
      ],
    );
  }

  Widget _tunSection(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SettingSection(
      title: "",
      children: [
        if (AppPlatform.isLinux || AppPlatform.isWindows)
          SettingRow(
            title: AppLocalizations.of(context)!.tunSettingUIPageTunName,
            value: state.tunSettingState.tunName,
          ),
        if (AppPlatform.isLinux) _tunPriority(context, controller),
        _tunDnsIPv4(context, controller),
        _tunDnsIPv6(context, controller),
        if (AppPlatform.isIOS || AppPlatform.isMacOS)
          _enableDot(context, state, controller),
        if ((AppPlatform.isIOS || AppPlatform.isMacOS) &&
            state.tunSettingState.enableDot)
          _tunDnsServerName(context, controller),
        _enableIPv6(context, state, controller),
      ],
    );
  }

  Widget _tunPriority(BuildContext context, TunSettingUIController controller) {
    return TextFieldSettingRow(
      controller: controller.tunPriorityController,
      label: AppLocalizations.of(context)!.tunSettingUIPageTunPriority,
      hintText: AppLocalizations.of(context)!.tunSettingUIPageTunPriority,
    );
  }

  Widget _tunDnsIPv4(BuildContext context, TunSettingUIController controller) {
    return TextFieldSettingRow(
      controller: controller.tunDnsIPv4Controller,
      label: AppLocalizations.of(context)!.tunSettingUIPageTunDnsIPv4,
      hintText: AppLocalizations.of(context)!.tunSettingUIPageTunDnsIPv4Example,
    );
  }

  Widget _tunDnsIPv6(BuildContext context, TunSettingUIController controller) {
    return TextFieldSettingRow(
      controller: controller.tunDnsIPv6Controller,
      label: AppLocalizations.of(context)!.tunSettingUIPageTunDnsIPv6,
      hintText: AppLocalizations.of(context)!.tunSettingUIPageTunDnsIPv6Example,
    );
  }

  Widget _enableDot(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.tunSettingUIPageTunDnsEnableDot,
      value: state.tunSettingState.enableDot,
      onChanged: (value) => controller.updateEnableDot(value),
    );
  }

  Widget _tunDnsServerName(
    BuildContext context,
    TunSettingUIController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.tunDnsServerNameController,
      label: AppLocalizations.of(context)!.tunSettingUIPageTunDnsServerName,
      hintText: AppLocalizations.of(
        context,
      )!.tunSettingUIPageTunDnsServerNameExample,
    );
  }

  Widget _enableIPv6(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.tunSettingUIPageEnableIPv6,
      value: state.tunSettingState.enableIPv6,
      onChanged: (value) => controller.updateEnableIPv6(value),
    );
  }

  Widget _interfaceSection(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SettingSection(
      title: "",
      children: [_interface(context, state, controller)],
    );
  }

  Widget _interface(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.tunSettingUIPageInterface,
      value: state.tunSettingState.bindInterface,
      onTap: () => controller.editInterface(context),
    );
  }

  Widget _onDemandSection(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SettingSection(
      title: "",
      children: [
        _onDemandEnabled(context, state, controller),
        if (state.tunSettingState.onDemandEnabled)
          ..._onDemandRulesSection(context, state, controller),
      ],
    );
  }

  Widget _onDemandEnabled(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.tunSettingUIPageOnDemandEnabled,
      value: state.tunSettingState.onDemandEnabled,
      onChanged: (value) => controller.updateOnDemandEnabled(value),
    );
  }

  List<Widget> _onDemandRulesSection(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    final ruleViews = state.tunSettingState.onDemandRules
        .mapIndexed(
          (index, rule) => _onDemandRuleCell(context, controller, rule, index),
        )
        .toList();
    return [
      SettingRow(
        title: AppLocalizations.of(context)!.tunSettingUIPageOnDemandRules,
        subtitle: AppLocalizations.of(context)!.helpOrder,
        trailing: IconButton(
          onPressed: () => controller.appendOnDemandRule(),
          icon: const Icon(Icons.add),
        ),
      ),
      if (ruleViews.isNotEmpty)
        ReorderableListView(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          onReorderItem: (int oldIndex, int newIndex) =>
              controller.sortOnDemandRule(
                oldIndex,
                _legacyReorderNewIndex(oldIndex, newIndex),
              ),
          children: ruleViews,
        ),
    ];
  }

  Widget _onDemandRuleCell(
    BuildContext context,
    TunSettingUIController controller,
    OnDemandRuleState rule,
    int index,
  ) {
    return ReorderableDelayedDragStartListener(
      key: Key("$index"),
      index: index,
      child: SettingRow(
        onTap: () => controller.editOnDemandRule(context, index),
        title: rule.interfaceType.name,
        subtitleWidget: Row(children: [TagView(tag: rule.mode.name)]),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconMenuPicker(
              icon: Icons.more_vert,
              menus: [IconMenuId.delete],
              callback: (menuId) => controller.moreAction(menuId, index),
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
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SettingSection(
      title: "",
      children: [
        _perAppVPNMode(context, state, controller),
        _appList(context, state, controller),
      ],
    );
  }

  Widget _perAppVPNMode(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.tunSettingUIPagePerAppVPNMode,
      value: state.tunSettingState.perAppVPNMode.name,
      selections: PerAppVPNMode.names,
      onSelected: (value) => controller.updatePerAppVPNMode(value),
    );
  }

  Widget _appList(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    var length = 0;
    switch (state.tunSettingState.perAppVPNMode) {
      case PerAppVPNMode.allow:
        length = state.tunSettingState.allowAppList.length;
        break;
      case PerAppVPNMode.disallow:
        length = state.tunSettingState.disallowAppList.length;
        break;
    }
    return NavigationSettingRow(
      title: AppLocalizations.of(context)!.tunSettingUIPagePerAppVPN,
      value: AppLocalizations.of(
        context,
      )!.tunSettingUIPagePerAppVPNCount("$length"),
      subtitle: AppLocalizations.of(context)!.tunSettingUIPagePerAppVPNHelp,
      onTap: () => controller.editAppList(context),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    TunSettingUIController controller,
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

  int _legacyReorderNewIndex(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      return newIndex + 1;
    }
    return newIndex;
  }
}
