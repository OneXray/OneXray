import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/xray/setting/dns/controller.dart';
import 'package:onexray/pages/core/xray/setting/dns/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/service/xray/setting/dns_server_state.dart';
import 'package:onexray/service/xray/setting/enum.dart';

class DnsPage extends StatelessWidget {
  final DnsParams params;

  const DnsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DnsController(params),
      child: BlocBuilder<DnsController, DnsCubitState>(
        builder: (context, state) {
          final controller = context.read<DnsController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.dnsPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
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
                    _hostsSection(context, controller),
                    _serversSection(context, controller, state),
                    _tagSection(context, controller, state),
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

  Widget _hostsSection(BuildContext context, DnsController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsPageSectionHosts,
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.dnsPageHosts,
          onTap: () => controller.editHosts(context),
        ),
      ],
    );
  }

  Widget _serversSection(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    final serverViews = state.dnsState.servers
        .mapIndexed(
          (index, server) => _serverCell(context, controller, server, index),
        )
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsPageSectionServers,
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.dnsPageServers,
          trailing: IconButton(
            onPressed: () => controller.appendServer(),
            icon: const Icon(Icons.add),
          ),
        ),
        if (serverViews.isNotEmpty)
          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            onReorderItem: (int oldIndex, int newIndex) =>
                controller.sortServer(
                  oldIndex,
                  _legacyReorderNewIndex(oldIndex, newIndex),
                ),
            children: serverViews,
          ),
      ],
    );
  }

  Widget _serverCell(
    BuildContext context,
    DnsController controller,
    DnsServerState server,
    int serverIndex,
  ) {
    final queryStrategy = server.queryStrategy;
    return ReorderableDelayedDragStartListener(
      key: Key("$serverIndex"),
      index: serverIndex,
      child: DataListRow(
        onTap: () => controller.editServer(context, serverIndex),
        title: server.address,
        tags: [TagView(tag: queryStrategy.name)],
        trailing: ActionCluster(
          children: [
            IconMenuPicker(
              icon: Icons.more_vert,
              menus: [IconMenuId.delete],
              callback: (menuId) => controller.moreAction(menuId, serverIndex),
            ),
            ReorderDragHandle(
              index: serverIndex,
              tooltip: AppLocalizations.of(context)!.helpOrder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagSection(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsPageSectionPolicy,
      children: [
        _tag(context, controller, state),
        _clientIp(context, controller),
        _queryStrategy(context, controller, state),
        _disableCache(context, controller, state),
        _serveStale(context, controller, state),
        _serveExpiredTTL(context, controller),
        _disableFallback(context, controller, state),
        _disableFallbackIfMatch(context, controller, state),
        _enableParallelQuery(context, controller, state),
        _useSystemHosts(context, controller, state),
      ],
    );
  }

  Widget _tag(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    return SettingRow(
      title: AppLocalizations.of(context)!.dnsPageTag,
      value: state.dnsState.tag,
    );
  }

  Widget _clientIp(BuildContext context, DnsController controller) {
    return TextFieldSettingRow(
      controller: controller.clientIpController,
      label: AppLocalizations.of(context)!.dnsPageClientIp,
      hintText: AppLocalizations.of(context)!.dnsPageClientIpExample,
    );
  }

  Widget _queryStrategy(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    return SelectSettingRow(
      title: AppLocalizations.of(context)!.dnsPageQueryStrategy,
      value: state.dnsState.queryStrategy.name,
      selections: DnsQueryStrategy.names,
      onSelected: (value) => controller.updateQueryStrategy(value),
    );
  }

  Widget _disableCache(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsPageDisableCache,
      value: state.dnsState.disableCache,
      onChanged: (value) => controller.updateDisableCache(value),
    );
  }

  Widget _serveStale(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsPageServeStale,
      value: state.dnsState.serveStale,
      onChanged: (value) => controller.updateServeStale(value),
    );
  }

  Widget _serveExpiredTTL(BuildContext context, DnsController controller) {
    return TextFieldSettingRow(
      controller: controller.serveExpiredTTLController,
      label: AppLocalizations.of(context)!.dnsPageServeExpiredTTL,
      hintText: AppLocalizations.of(context)!.dnsPageServeExpiredTTLExample,
    );
  }

  Widget _disableFallback(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsPageDisableFallback,
      value: state.dnsState.disableFallback,
      onChanged: (value) => controller.updateDisableFallback(value),
    );
  }

  Widget _disableFallbackIfMatch(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsPageDisableFallbackIfMatch,
      value: state.dnsState.disableFallbackIfMatch,
      onChanged: (value) => controller.updateDisableFallbackIfMatch(value),
    );
  }

  Widget _enableParallelQuery(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsPageEnableParallelQuery,
      value: state.dnsState.enableParallelQuery,
      onChanged: (value) => controller.updateEnableParallelQuery(value),
    );
  }

  Widget _useSystemHosts(
    BuildContext context,
    DnsController controller,
    DnsCubitState state,
  ) {
    return SwitchSettingRow(
      title: AppLocalizations.of(context)!.dnsPageUseSystemHosts,
      value: state.dnsState.useSystemHosts,
      onChanged: (value) => controller.updateUseSystemHosts(value),
    );
  }

  Widget _bottomButton(BuildContext context, DnsController controller) {
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
