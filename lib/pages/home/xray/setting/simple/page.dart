import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/simple/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';

class XraySettingSimplePage extends StatelessWidget {
  const XraySettingSimplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XraySettingSimpleController(),
      child:
          BlocBuilder<XraySettingSimpleController, XraySettingSimpleCubitState>(
            builder: (context, state) {
              final controller = context.read<XraySettingSimpleController>();
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    AppLocalizations.of(context)!.xraySettingSimplePageTitle,
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
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ResponsiveContent(
                child: Column(
                  children: [
                    _logSection(context, controller, state),
                    _chainProxySection(context, controller, state),
                    _routingSection(context, controller, state),
                    _fakeDnsSection(context, controller, state),
                    _dnsSection(context, controller, state),
                  ],
                ),
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _logSection(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.logPageTitle,
      children: [
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.xraySettingSimplePageEnableLog,
          value: state.xraySetting.enableLog,
          onChanged: (value) => controller.updateEnableLog(value),
        ),
      ],
    );
  }

  Widget _routingSection(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.xraySettingSimplePageRouting,
      children: [
        _domainStrategy(context, controller, state),
        _queryStrategy(context, controller, state),
        _directSet(context, controller, state),
        _appleDirect(context, controller, state),
        _localDirect(context, controller, state),
        _enableIPRule(context, controller, state),
        _localDns(context, controller, state),
      ],
    );
  }

  Widget _fakeDnsSection(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.fakeDnsPageTitle,
      children: [
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.xraySettingSimplePageFakeDns,
          value: state.xraySetting.fakeDns,
          onChanged: (value) => controller.updateFakeDns(value),
        ),
      ],
    );
  }

  Widget _chainProxySection(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    final chainProxyName = state.chainProxyName.isEmpty
        ? AppLocalizations.of(context)!.chainProxyPageDisabled
        : state.chainProxyName;
    return SettingSection(
      title: AppLocalizations.of(context)!.xraySettingSimplePageChainProxy,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.xraySettingSimplePageChainProxy,
          value: chainProxyName,
          onTap: () => controller.editChainProxy(context),
          showChevron: state.xraySetting.chainProxyOutboundId == null,
          trailing: state.xraySetting.chainProxyOutboundId == null
              ? null
              : IconButton(
                  onPressed: () => controller.clearChainProxy(),
                  icon: const Icon(Icons.clear),
                ),
        ),
      ],
    );
  }

  Widget _domainStrategy(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.xraySettingSimplePageDomainStrategy,
      value: state.xraySetting.routing.domainStrategy.name,
      selections: RoutingDomainStrategy.simpleStrategy,
      onSelected: (value) => controller.updateDomainStrategy(value),
    );
  }

  Widget _queryStrategy(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.xraySettingSimplePageQueryStrategy,
      value: state.xraySetting.routing.queryStrategy.name,
      selections: DnsQueryStrategy.names,
      onSelected: (value) => controller.updateQueryStrategy(value),
    );
  }

  Widget _directSet(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.xraySettingSimplePageDirectSet,
      value: state.xraySetting.routing.directSet.name,
      selections: SimpleCountry.names,
      onSelected: (value) => controller.updateDirectSet(value),
    );
  }

  Widget _appleDirect(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.xraySettingSimplePageAppleDirect,
      value: state.xraySetting.routing.appleDirect,
      onChanged: (value) => controller.updateAppleDirect(value),
    );
  }

  Widget _localDirect(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.xraySettingSimplePageLocalDirect,
      value: state.xraySetting.routing.localDirect,
      onChanged: (value) => controller.updateLocalDirect(value),
    );
  }

  Widget _enableIPRule(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.xraySettingSimplePageEnableIPRule,
      value: state.xraySetting.routing.enableIPRule,
      onChanged: (value) => controller.updateEnableIPRule(value),
    );
  }

  Widget _localDns(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.xraySettingSimplePageLocalDns,
      value: state.xraySetting.routing.localDns,
      onChanged: (value) => controller.updateLocalDns(value),
    );
  }

  Widget _dnsSection(
    BuildContext context,
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
  ) {
    final children = SimpleDns.values
        .map((e) => _simpleDns(controller, state, e))
        .toList();
    return RadioGroup<int>(
      groupValue: state.xraySetting.dns.id,
      onChanged: (value) => controller.updateDnsId(value),
      child: SettingSection(
        title: AppLocalizations.of(context)!.xraySettingSimplePageDns,
        children: children,
      ),
    );
  }

  Widget _simpleDns(
    XraySettingSimpleController controller,
    XraySettingSimpleCubitState state,
    SimpleDns dns,
  ) {
    final queryStrategy = state.xraySetting.routing.queryStrategy;
    return SettingRow(
      title: dns.address,
      subtitleWidget: Row(
        children: [
          TagView(tag: dns.outbound.name),
          TagView(tag: queryStrategy.name),
        ],
      ),
      onTap: () => controller.updateDnsId(dns.id),
      trailing: Radio<int>(value: dns.id),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    XraySettingSimpleController controller,
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
