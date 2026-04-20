import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/dns_server/controller.dart';
import 'package:onexray/pages/home/xray/setting/dns_server/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/service/xray/setting/enum.dart';

class DnsServerPage extends StatelessWidget {
  final DnsServerParams params;

  const DnsServerPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DnsServerController(params),
      child: BlocBuilder<DnsServerController, DnsServerCubitState>(
        builder: (context, state) {
          final controller = context.read<DnsServerController>();
          return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.dnsServerPageTitle),
        ),
        body: SafeArea(child: _body(context, controller, state)),
      );
        },
      ),
    );
  }

  Widget _body(BuildContext context, DnsServerController controller, DnsServerCubitState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _addressSection(context, controller, state),
                  _domainsSection(context, controller, state),
                  _expectedIPsSection(context, controller, state),
                  _unexpectedIPsSection(context, controller, state),
                  _queryStrategySection(context, controller, state),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _addressSection(BuildContext context, DnsServerController controller, DnsServerCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          _address(context, controller),
          _port(context, controller),
          _skipFallback(context, controller, state),
        ],
      ),
    );
  }

  Widget _address(BuildContext context, DnsServerController controller) {
    return TextField(
      controller: controller.addressController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.dnsServerPageAddress),
        hintText: AppLocalizations.of(context)!.dnsServerPageAddressExample,
      ),
    );
  }

  Widget _port(BuildContext context, DnsServerController controller) {
    return TextField(
      controller: controller.portController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.dnsServerPagePort),
        hintText: AppLocalizations.of(context)!.dnsServerPagePortExample,
      ),
    );
  }

  Widget _skipFallback(BuildContext context, DnsServerController controller, DnsServerCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.dnsServerPageSkipFallback),
        Switch(
          value: state.serverState.skipFallback,
          onChanged: (value) => controller.updateSkipFallback(value),
        ),
      ],
    );
  }

  Widget _domainsSection(BuildContext context, DnsServerController controller, DnsServerCubitState state) {
    final domainsViews = state.serverState.domains
        .mapIndexed(
          (index, host) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.domainsControllers[index],
                  decoration: InputDecoration(
                    label: Text(
                      AppLocalizations.of(context)!.dnsServerPageDomain,
                    ),
                    hintText: AppLocalizations.of(
                      context,
                    )!.dnsServerPageDomainExample,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.deleteDomains(context, index),
                icon: Icon(Icons.delete),
              ),
            ],
          ),
        )
        .toList();
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            children: [
              Text(AppLocalizations.of(context)!.dnsServerPageDomains),
              const Spacer(),
              IconButton(
                onPressed: () => controller.appendDomains(),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                onPressed: () => controller.importDomain(context),
                icon: const Icon(Icons.list),
              ),
            ],
          ),
          if (domainsViews.isNotEmpty) Column(children: domainsViews),
        ],
      ),
    );
  }

  Widget _expectedIPsSection(
    BuildContext context,
    DnsServerController controller, DnsServerCubitState state) {
    final expectedIPsViews = state.serverState.expectedIPs
        .mapIndexed(
          (index, host) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.expectedIPsControllers[index],
                  decoration: InputDecoration(
                    label: Text(AppLocalizations.of(context)!.dnsServerPageIp),
                    hintText: AppLocalizations.of(
                      context,
                    )!.dnsServerPageIpExample,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.deleteExpectedIPs(context, index),
                icon: Icon(Icons.delete),
              ),
            ],
          ),
        )
        .toList();
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            children: [
              Text(AppLocalizations.of(context)!.dnsServerPageExpectedIPs),
              const Spacer(),
              IconButton(
                onPressed: () => controller.appendExpectedIPs(),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                onPressed: () => controller.importExpectedIPs(context),
                icon: const Icon(Icons.list),
              ),
            ],
          ),
          if (expectedIPsViews.isNotEmpty) Column(children: expectedIPsViews),
        ],
      ),
    );
  }

  Widget _unexpectedIPsSection(
    BuildContext context,
    DnsServerController controller, DnsServerCubitState state) {
    final unexpectedIPsViews = state.serverState.unexpectedIPs
        .mapIndexed(
          (index, host) => Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller.unexpectedIPsControllers[index],
                  decoration: InputDecoration(
                    label: Text(AppLocalizations.of(context)!.dnsServerPageIp),
                    hintText: AppLocalizations.of(
                      context,
                    )!.dnsServerPageIpExample,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.deleteUnexpectedIPs(context, index),
                icon: Icon(Icons.delete),
              ),
            ],
          ),
        )
        .toList();
    return SectionView(
      title: "",
      child: Column(
        children: [
          Row(
            children: [
              Text(AppLocalizations.of(context)!.dnsServerPageUnexpectedIPs),
              const Spacer(),
              IconButton(
                onPressed: () => controller.appendUnexpectedIPs(),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                onPressed: () => controller.importUnexpectedIPs(context),
                icon: const Icon(Icons.list),
              ),
            ],
          ),
          if (unexpectedIPsViews.isNotEmpty)
            Column(children: unexpectedIPsViews),
        ],
      ),
    );
  }

  Widget _queryStrategySection(
    BuildContext context,
    DnsServerController controller, DnsServerCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          _queryStrategy(context, controller, state),
          _tag(context, controller),
          _disableCache(context, controller, state),
          _finalQuery(context, controller, state),
        ],
      ),
    );
  }

  Widget _queryStrategy(BuildContext context, DnsServerController controller, DnsServerCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.dnsServerPageQueryStrategy),
        TextMenuPicker(
          title: state.serverState.queryStrategy.name,
          selections: DnsQueryStrategy.names,
          callback: (value) => controller.updateQueryStrategy(value),
        ),
      ],
    );
  }

  Widget _tag(BuildContext context, DnsServerController controller) {
    return TextField(
      controller: controller.tagController,
      decoration: InputDecoration(
        label: Text(AppLocalizations.of(context)!.dnsServerPageTag),
        hintText: AppLocalizations.of(context)!.dnsServerPageTag,
      ),
    );
  }

  Widget _disableCache(BuildContext context, DnsServerController controller, DnsServerCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.dnsServerPageDisableCache),
        Switch(
          value: state.serverState.disableCache,
          onChanged: (value) => controller.updateDisableCache(value),
        ),
      ],
    );
  }

  Widget _finalQuery(BuildContext context, DnsServerController controller, DnsServerCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.dnsServerPageFinalQuery),
        Switch(
          value: state.serverState.finalQuery,
          onChanged: (value) => controller.updateFinalQuery(value),
        ),
      ],
    );
  }

  Widget _bottomButton(BuildContext context, DnsServerController controller) {
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
