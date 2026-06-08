import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/controller.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/xray/setting/enum.dart';

class OutboundDnsPage extends StatelessWidget {
  final OutboundDnsParams params;

  const OutboundDnsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OutboundDnsController(params),
      child: BlocBuilder<OutboundDnsController, OutboundDnsCubitState>(
        builder: (context, state) {
          final controller = context.read<OutboundDnsController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.outboundDnsPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _protocolSection(context, controller, state),
                  _settingSection(context, controller, state),
                  _sockoptSection(context, controller, state),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _protocolSection(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.outboundDnsPageProtocol,
          value: state.dnsState.protocol.name,
        ),
        SettingRow(
          title: AppLocalizations.of(context)!.outboundDnsPageTag,
          value: state.dnsState.tag.name,
        ),
      ],
    );
  }

  Widget _settingSection(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundDnsPageSettings,
      children: [
        _network(context, controller, state),
        _address(context, controller),
        _port(context, controller),
        _nonIPQuery(context, controller, state),
      ],
    );
  }

  Widget _network(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundDnsPageNetwork,
      value: state.dnsState.network.name,
      selections: DnsNetwork.names,
      onSelected: (value) => controller.updateNetwork(value),
    );
  }

  Widget _address(BuildContext context, OutboundDnsController controller) {
    return TextFieldSettingRow(
      controller: controller.addressController,
      label: AppLocalizations.of(context)!.outboundDnsPageAddress,
      hintText: AppLocalizations.of(context)!.outboundDnsPageAddress,
    );
  }

  Widget _port(BuildContext context, OutboundDnsController controller) {
    return TextFieldSettingRow(
      controller: controller.portController,
      label: AppLocalizations.of(context)!.outboundDnsPagePort,
      hintText: AppLocalizations.of(context)!.outboundDnsPagePort,
    );
  }

  Widget _nonIPQuery(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundDnsPageNonIPQuery,
      value: state.dnsState.nonIPQuery.name,
      selections: DnsNonIPQuery.names,
      onSelected: (value) => controller.updateNonIPQuery(value),
    );
  }

  Widget _sockoptSection(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.outboundDnsPageSockopt,
      children: [_sockopt(context, controller, state)],
    );
  }

  Widget _sockopt(
    BuildContext context,
    OutboundDnsController controller,
    OutboundDnsCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.outboundDnsPageDialerProxy,
      value: state.dnsState.dialerProxy,
      selections: state.outboundTags,
      onSelected: (value) => controller.updateDialerProxy(value),
    );
  }

  Widget _bottomButton(BuildContext context, OutboundDnsController controller) {
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
