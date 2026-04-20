import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/controller.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/text_row.dart';
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

  Widget _body(BuildContext context, OutboundDnsController controller, OutboundDnsCubitState state) {
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
    OutboundDnsController controller, OutboundDnsCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.outboundDnsPageProtocol,
            detail: state.dnsState.protocol.name,
          ),
          TextRow(
            title: AppLocalizations.of(context)!.outboundDnsPageTag,
            detail: state.dnsState.tag.name,
          ),
        ],
      ),
    );
  }

  Widget _settingSection(
    BuildContext context,
    OutboundDnsController controller, OutboundDnsCubitState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundDnsPageSettings,
      child: Column(
        children: [
          _network(context, controller, state),
          _address(context, controller),
          _port(context, controller),
          _nonIPQuery(context, controller, state),
        ],
      ),
    );
  }

  Widget _network(BuildContext context, OutboundDnsController controller, OutboundDnsCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundDnsPageNetwork),
        TextMenuPicker(
          title: state.dnsState.network.name,
          selections: DnsNetwork.names,
          callback: (value) => controller.updateNetwork(value),
        ),
      ],
    );
  }

  Widget _address(BuildContext context, OutboundDnsController controller) {
    return TextField(
      controller: controller.addressController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundDnsPageAddress),
        hintText: AppLocalizations.of(context)!.outboundDnsPageAddress,
      ),
    );
  }

  Widget _port(BuildContext context, OutboundDnsController controller) {
    return TextField(
      controller: controller.portController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.outboundDnsPagePort),
        hintText: AppLocalizations.of(context)!.outboundDnsPagePort,
      ),
    );
  }

  Widget _nonIPQuery(BuildContext context, OutboundDnsController controller, OutboundDnsCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundDnsPageNonIPQuery),
        TextMenuPicker(
          title: state.dnsState.nonIPQuery.name,
          selections: DnsNonIPQuery.names,
          callback: (value) => controller.updateNonIPQuery(value),
        ),
      ],
    );
  }

  Widget _sockoptSection(
    BuildContext context,
    OutboundDnsController controller, OutboundDnsCubitState state) {
    return SectionView(
      title: AppLocalizations.of(context)!.outboundDnsPageSockopt,
      child: _sockopt(context, controller, state),
    );
  }

  Widget _sockopt(BuildContext context, OutboundDnsController controller, OutboundDnsCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.outboundDnsPageDialerProxy),
        TextMenuPicker(
          title: state.dnsState.dialerProxy,
          selections: state.outboundTags,
          callback: (value) => controller.updateDialerProxy(value),
        ),
      ],
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
