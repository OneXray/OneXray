import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/dns_server/controller.dart';
import 'package:onexray/pages/home/xray/setting/dns_server/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
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

  Widget _body(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
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
                    _addressSection(context, controller, state),
                    _domainsSection(context, controller, state),
                    _expectedIPsSection(context, controller, state),
                    _unexpectedIPsSection(context, controller, state),
                    _queryStrategySection(context, controller, state),
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

  Widget _addressSection(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsServerPageSectionAddress,
      children: [
        _address(context, controller),
        _clientIp(context, controller),
        _port(context, controller),
        _skipFallback(context, controller, state),
      ],
    );
  }

  Widget _address(BuildContext context, DnsServerController controller) {
    return TextFieldSettingRow(
      controller: controller.addressController,
      label: AppLocalizations.of(context)!.dnsServerPageAddress,
      hintText: AppLocalizations.of(context)!.dnsServerPageAddressExample,
    );
  }

  Widget _clientIp(BuildContext context, DnsServerController controller) {
    return TextFieldSettingRow(
      controller: controller.clientIpController,
      label: AppLocalizations.of(context)!.dnsServerPageClientIp,
      hintText: AppLocalizations.of(context)!.dnsServerPageClientIpExample,
    );
  }

  Widget _port(BuildContext context, DnsServerController controller) {
    return TextFieldSettingRow(
      controller: controller.portController,
      label: AppLocalizations.of(context)!.dnsServerPagePort,
      hintText: AppLocalizations.of(context)!.dnsServerPagePortExample,
    );
  }

  Widget _skipFallback(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsServerPageSkipFallback,
      value: state.serverState.skipFallback,
      onChanged: (value) => controller.updateSkipFallback(value),
    );
  }

  Widget _domainsSection(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    final domainsViews = state.serverState.domains
        .mapIndexed(
          (index, host) => TextFieldActionSettingRow(
            controller: controller.domainsControllers[index],
            label: AppLocalizations.of(context)!.dnsServerPageDomain,
            hintText: AppLocalizations.of(context)!.dnsServerPageDomainExample,
            trailing: IconButton(
              onPressed: () => controller.deleteDomains(context, index),
              icon: Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsServerPageSectionDomains,
      separated: false,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.dnsServerPageDomains,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
        ),
        if (domainsViews.isNotEmpty) Column(children: domainsViews),
      ],
    );
  }

  Widget _expectedIPsSection(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    final expectedIPsViews = state.serverState.expectedIPs
        .mapIndexed(
          (index, host) => TextFieldActionSettingRow(
            controller: controller.expectedIPsControllers[index],
            label: AppLocalizations.of(context)!.dnsServerPageIp,
            hintText: AppLocalizations.of(context)!.dnsServerPageIpExample,
            trailing: IconButton(
              onPressed: () => controller.deleteExpectedIPs(context, index),
              icon: Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsServerPageSectionExpectedIPs,
      separated: false,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.dnsServerPageExpectedIPs,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
        ),
        if (expectedIPsViews.isNotEmpty) Column(children: expectedIPsViews),
      ],
    );
  }

  Widget _unexpectedIPsSection(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    final unexpectedIPsViews = state.serverState.unexpectedIPs
        .mapIndexed(
          (index, host) => TextFieldActionSettingRow(
            controller: controller.unexpectedIPsControllers[index],
            label: AppLocalizations.of(context)!.dnsServerPageIp,
            hintText: AppLocalizations.of(context)!.dnsServerPageIpExample,
            trailing: IconButton(
              onPressed: () => controller.deleteUnexpectedIPs(context, index),
              icon: Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsServerPageSectionUnexpectedIPs,
      separated: false,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.dnsServerPageUnexpectedIPs,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
        ),
        if (unexpectedIPsViews.isNotEmpty) Column(children: unexpectedIPsViews),
      ],
    );
  }

  Widget _queryStrategySection(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsServerPageSectionPolicy,
      children: [
        _queryStrategy(context, controller, state),
        _tag(context, controller),
        _timeoutMs(context, controller),
        _disableCache(context, controller, state),
        _serveStale(context, controller, state),
        _serveExpiredTTL(context, controller),
        _finalQuery(context, controller, state),
      ],
    );
  }

  Widget _queryStrategy(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.dnsServerPageQueryStrategy,
      value: state.serverState.queryStrategy.name,
      selections: DnsQueryStrategy.names,
      onSelected: (value) => controller.updateQueryStrategy(value),
    );
  }

  Widget _tag(BuildContext context, DnsServerController controller) {
    return TextFieldSettingRow(
      controller: controller.tagController,
      label: AppLocalizations.of(context)!.dnsServerPageTag,
      hintText: AppLocalizations.of(context)!.dnsServerPageTag,
    );
  }

  Widget _timeoutMs(BuildContext context, DnsServerController controller) {
    return TextFieldSettingRow(
      controller: controller.timeoutMsController,
      label: AppLocalizations.of(context)!.dnsServerPageTimeoutMs,
      hintText: AppLocalizations.of(context)!.dnsServerPageTimeoutMsExample,
    );
  }

  Widget _disableCache(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsServerPageDisableCache,
      value: state.serverState.disableCache,
      onChanged: (value) => controller.updateDisableCache(value),
    );
  }

  Widget _serveStale(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsServerPageServeStale,
      value: state.serverState.serveStale,
      onChanged: (value) => controller.updateServeStale(value),
    );
  }

  Widget _serveExpiredTTL(
    BuildContext context,
    DnsServerController controller,
  ) {
    return TextFieldSettingRow(
      controller: controller.serveExpiredTTLController,
      label: AppLocalizations.of(context)!.dnsServerPageServeExpiredTTL,
      hintText: AppLocalizations.of(
        context,
      )!.dnsServerPageServeExpiredTTLExample,
    );
  }

  Widget _finalQuery(
    BuildContext context,
    DnsServerController controller,
    DnsServerCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsServerPageFinalQuery,
      value: state.serverState.finalQuery,
      onChanged: (value) => controller.updateFinalQuery(value),
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
