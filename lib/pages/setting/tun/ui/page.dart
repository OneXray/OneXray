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
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/pages/widget/text_row.dart';
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
    return SectionView(
      title: "",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (AppPlatform.isLinux || AppPlatform.isWindows)
            TextRow(
              title: AppLocalizations.of(context)!.tunSettingUIPageTunName,
              detail: state.tunSettingState.tunName,
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
      ),
    );
  }

  Widget _tunPriority(BuildContext context, TunSettingUIController controller) {
    return TextField(
      controller: controller.tunPriorityController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.tunSettingUIPageTunPriority),
        hintText: AppLocalizations.of(context)!.tunSettingUIPageTunPriority,
      ),
    );
  }

  Widget _tunDnsIPv4(BuildContext context, TunSettingUIController controller) {
    return TextField(
      controller: controller.tunDnsIPv4Controller,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.tunSettingUIPageTunDnsIPv4),
        hintText: AppLocalizations.of(
          context,
        )!.tunSettingUIPageTunDnsIPv4Example,
      ),
    );
  }

  Widget _tunDnsIPv6(BuildContext context, TunSettingUIController controller) {
    return TextField(
      controller: controller.tunDnsIPv6Controller,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.tunSettingUIPageTunDnsIPv6),
        hintText: AppLocalizations.of(
          context,
        )!.tunSettingUIPageTunDnsIPv6Example,
      ),
    );
  }

  Widget _enableDot(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.tunSettingUIPageTunDnsEnableDot),
        Switch(
          value: state.tunSettingState.enableDot,
          onChanged: (value) => controller.updateEnableDot(value),
        ),
      ],
    );
  }

  Widget _tunDnsServerName(
    BuildContext context,
    TunSettingUIController controller,
  ) {
    return TextField(
      controller: controller.tunDnsServerNameController,
      decoration: InputDecoration(
        label: Text(
          AppLocalizations.of(context)!.tunSettingUIPageTunDnsServerName,
        ),
        hintText: AppLocalizations.of(
          context,
        )!.tunSettingUIPageTunDnsServerNameExample,
      ),
    );
  }

  Widget _enableIPv6(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.tunSettingUIPageEnableIPv6),
        Switch(
          value: state.tunSettingState.enableIPv6,
          onChanged: (value) => controller.updateEnableIPv6(value),
        ),
      ],
    );
  }

  Widget _interfaceSection(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SectionView(
      title: "",
      child: _interface(context, state, controller),
    );
  }

  Widget _interface(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return InkWell(
      onTap: () => controller.editInterface(context),
      child: TextRow(
        title: AppLocalizations.of(context)!.tunSettingUIPageInterface,
        detail: state.tunSettingState.bindInterface,
      ),
    );
  }

  Widget _onDemandSection(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          _onDemandEnabled(context, state, controller),
          if (state.tunSettingState.onDemandEnabled)
            _onDemandRulesSection(context, state, controller),
        ],
      ),
    );
  }

  Widget _onDemandEnabled(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.tunSettingUIPageOnDemandEnabled),
        Switch(
          value: state.tunSettingState.onDemandEnabled,
          onChanged: (value) => controller.updateOnDemandEnabled(value),
        ),
      ],
    );
  }

  Widget _onDemandRulesSection(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    final ruleViews = state.tunSettingState.onDemandRules
        .mapIndexed(
          (index, rule) => _onDemandRuleCell(context, controller, rule, index),
        )
        .toList();
    return SectionView(
      title: AppLocalizations.of(context)!.helpOrder,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.tunSettingUIPageOnDemandRules),
              IconButton(
                onPressed: () => controller.appendOnDemandRule(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (ruleViews.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              onReorder: (int oldIndex, int newIndex) =>
                  controller.sortOnDemandRule(oldIndex, newIndex),
              children: ruleViews,
            ),
        ],
      ),
    );
  }

  Widget _onDemandRuleCell(
    BuildContext context,
    TunSettingUIController controller,
    OnDemandRuleState rule,
    int index,
  ) {
    var contentPadding = EdgeInsetsDirectional.symmetric(horizontal: 16);
    if (AppPlatform.isDesktop) {
      contentPadding = EdgeInsetsDirectional.only(start: 16, end: 40);
    }
    return ListTile(
      key: Key("$index"),
      contentPadding: contentPadding,
      onTap: () => controller.editOnDemandRule(context, index),
      title: Text(rule.interfaceType.name),
      subtitle: Row(children: [TagView(tag: rule.mode.name)]),
      trailing: IconMenuPicker(
        icon: Icons.more_vert,
        menus: [IconMenuId.delete],
        callback: (menuId) => controller.moreAction(menuId, index),
      ),
    );
  }

  Widget _perAppVPNSection(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          _perAppVPNMode(context, state, controller),
          _appList(context, state, controller),
        ],
      ),
    );
  }

  Widget _perAppVPNMode(
    BuildContext context,
    TunSettingUIState state,
    TunSettingUIController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.tunSettingUIPagePerAppVPNMode),
        TextMenuPicker(
          title: state.tunSettingState.perAppVPNMode.name,
          selections: PerAppVPNMode.names,
          callback: (value) => controller.updatePerAppVPNMode(value),
        ),
      ],
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
    return ListTile(
      onTap: () => controller.editAppList(context),
      title: Text(AppLocalizations.of(context)!.tunSettingUIPagePerAppVPN),
      subtitle: Text(
        AppLocalizations.of(context)!.tunSettingUIPagePerAppVPNHelp,
      ),
      trailing: Text(
        AppLocalizations.of(context)!.tunSettingUIPagePerAppVPNCount("$length"),
      ),
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
}
