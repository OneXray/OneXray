import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/xray/profile/simple/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/simple_state_writer.dart';

class XrayProfileSimplePage extends StatelessWidget {
  const XrayProfileSimplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayProfileSimpleController(),
      child:
          BlocBuilder<XrayProfileSimpleController, XrayProfileSimplePageState>(
            builder: (context, state) {
              final controller = context.read<XrayProfileSimpleController>();
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    AppLocalizations.of(context)!.xrayProfileSimplePageTitle,
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
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
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
                    _proxySection(context, state),
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
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.logPageTitle,
      children: [
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.xrayProfileSimplePageEnableLog,
          value: state.xrayProfile.enableLog,
          onChanged: (value) => controller.updateEnableLog(value),
        ),
      ],
    );
  }

  Widget _proxySection(BuildContext context, XrayProfileSimplePageState state) {
    final inbounds = state.xrayProfile.xrayProfileState.inbounds;
    return SettingSection(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageProxy,
      children: [
        SettingRow(
          title: inbounds.socks.tag.name,
          value: _proxyListenPort(
            context,
            inbounds.socks.listen,
            inbounds.socks.port,
          ),
        ),
        SettingRow(
          title: inbounds.http.tag.name,
          value: _proxyListenPort(
            context,
            inbounds.http.listen,
            inbounds.http.port,
          ),
        ),
      ],
    );
  }

  String _proxyListenPort(BuildContext context, String listen, String port) {
    final listenText = listen.isEmpty
        ? AppLocalizations.of(context)!.inboundProxyPageAllInterfaces
        : listen;
    return "$listenText:$port";
  }

  Widget _routingSection(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageRouting,
      children: [
        _domainStrategy(context, controller, state),
        _queryStrategy(context, controller, state),
        _directSet(context, controller, state),
        _appleDirect(context, controller, state),
        _localDirect(context, controller, state),
        _blockAds(context, controller, state),
        _enableIPRule(context, controller, state),
        _localDns(context, controller, state),
      ],
    );
  }

  Widget _fakeDnsSection(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.fakeDnsPageTitle,
      children: [
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.xrayProfileSimplePageFakeDns,
          value: state.xrayProfile.fakeDns,
          onChanged: (value) => controller.updateFakeDns(value),
        ),
      ],
    );
  }

  Widget _chainProxySection(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    final chainProxyName = state.chainProxyName.isEmpty
        ? AppLocalizations.of(context)!.chainProxyPageDisabled
        : state.chainProxyName;
    return SettingSection(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageChainProxy,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.xrayProfileSimplePageChainProxy,
          value: chainProxyName,
          onTap: () => controller.editChainProxy(context),
          showChevron: state.xrayProfile.chainProxyOutboundId == null,
          trailing: state.xrayProfile.chainProxyOutboundId == null
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
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageDomainStrategy,
      value: state.xrayProfile.routing.domainStrategy.name,
      selections: RoutingDomainStrategy.simpleStrategy,
      onSelected: (value) => controller.updateDomainStrategy(value),
    );
  }

  Widget _queryStrategy(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageQueryStrategy,
      value: state.xrayProfile.routing.queryStrategy.name,
      selections: DnsQueryStrategy.names,
      onSelected: (value) => controller.updateQueryStrategy(value),
    );
  }

  Widget _directSet(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageDirectSet,
      value: state.xrayProfile.routing.directSet.name,
      selections: SimpleCountry.names,
      onSelected: (value) => controller.updateDirectSet(value),
    );
  }

  Widget _appleDirect(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageAppleDirect,
      value: state.xrayProfile.routing.appleDirect,
      onChanged: (value) => controller.updateAppleDirect(value),
    );
  }

  Widget _localDirect(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageLocalDirect,
      value: state.xrayProfile.routing.localDirect,
      onChanged: (value) => controller.updateLocalDirect(value),
    );
  }

  Widget _enableIPRule(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageEnableIPRule,
      value: state.xrayProfile.routing.enableIPRule,
      onChanged: (value) => controller.updateEnableIPRule(value),
    );
  }

  Widget _blockAds(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageBlockAds,
      value: state.xrayProfile.routing.blockAds,
      onChanged: (value) => controller.updateBlockAds(value),
    );
  }

  Widget _localDns(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.xrayProfileSimplePageLocalDns,
      value: state.xrayProfile.routing.localDns,
      onChanged: (value) => controller.updateLocalDns(value),
    );
  }

  Widget _dnsSection(
    BuildContext context,
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
  ) {
    final children = SimpleDns.values
        .map((e) => _simpleDns(controller, state, e))
        .toList();
    return RadioGroup<int>(
      groupValue: state.xrayProfile.dns.id,
      onChanged: (value) => controller.updateDnsId(value),
      child: SettingSection(
        title: AppLocalizations.of(context)!.xrayProfileSimplePageDns,
        children: children,
      ),
    );
  }

  Widget _simpleDns(
    XrayProfileSimpleController controller,
    XrayProfileSimplePageState state,
    SimpleDns dns,
  ) {
    final queryStrategy = state.xrayProfile.routing.queryStrategy;
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
    XrayProfileSimpleController controller,
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
