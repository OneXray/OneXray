import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/dns/controller.dart';
import 'package:onexray/pages/home/xray/setting/dns/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/tag_view.dart';
import 'package:onexray/pages/widget/text_row.dart';
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
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.dnsPageTitle)),
        body: SafeArea(child: _body(context, controller, state)),
      );
        },
      ),
    );
  }

  Widget _body(BuildContext context, DnsController controller, DnsCubitState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _hostsSection(context, controller),
                  _serversSection(context, controller, state),
                  _tagSection(context, controller, state),
                ],
              ),
            ),
          ),
          _bottomButton(context, controller),
        ],
      ),
    );
  }

  Widget _hostsSection(BuildContext context, DnsController controller) {
    return SectionView(
      title: "",
      child: ListTile(
        onTap: () => controller.editHosts(context),
        title: Text(AppLocalizations.of(context)!.dnsPageHosts),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _serversSection(BuildContext context, DnsController controller, DnsCubitState state) {
    final serverViews = state.dnsState.servers
        .mapIndexed(
          (index, server) => _serverCell(context, controller, server, index),
        )
        .toList();
    return SectionView(
      title: AppLocalizations.of(context)!.helpOrder,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.dnsPageServers),
              IconButton(
                onPressed: () => controller.appendServer(),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (serverViews.isNotEmpty)
            ReorderableListView(
              shrinkWrap: true,
              onReorder: (int oldIndex, int newIndex) =>
                  controller.sortServer(oldIndex, newIndex),
              children: serverViews,
            ),
        ],
      ),
    );
  }

  Widget _serverCell(
    BuildContext context,
    DnsController controller,
    DnsServerState server,
    int serverIndex,
  ) {
    final queryStrategy = server.queryStrategy;
    var contentPadding = EdgeInsetsDirectional.symmetric(horizontal: 16);
    if (AppPlatform.isDesktop) {
      contentPadding = EdgeInsetsDirectional.only(start: 16, end: 40);
    }
    return ListTile(
      key: Key("$serverIndex"),
      contentPadding: contentPadding,
      onTap: () => controller.editServer(context, serverIndex),
      title: Text(server.address),
      subtitle: Row(children: [TagView(tag: queryStrategy.name)]),
      trailing: IconMenuPicker(
        icon: Icons.more_vert,
        menus: [IconMenuId.delete],
        callback: (menuId) => controller.moreAction(menuId, serverIndex),
      ),
    );
  }

  Widget _tagSection(BuildContext context, DnsController controller, DnsCubitState state) {
    return SectionView(
      title: "",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tag(context, controller, state),
          _queryStrategy(context, controller, state),
          _disableCache(context, controller, state),
          _disableFallback(context, controller, state),
          _disableFallbackIfMatch(context, controller, state),
          _useSystemHosts(context, controller, state),
        ],
      ),
    );
  }

  Widget _tag(BuildContext context, DnsController controller, DnsCubitState state) {
    return TextRow(
      title: AppLocalizations.of(context)!.dnsPageTag,
      detail: state.dnsState.tag,
    );
  }

  Widget _queryStrategy(BuildContext context, DnsController controller, DnsCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.dnsPageQueryStrategy),
        TextMenuPicker(
          title: state.dnsState.queryStrategy.name,
          selections: DnsQueryStrategy.names,
          callback: (value) => controller.updateQueryStrategy(value),
        ),
      ],
    );
  }

  Widget _disableCache(BuildContext context, DnsController controller, DnsCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.dnsPageDisableCache),
        Switch(
          value: state.dnsState.disableCache,
          onChanged: (value) => controller.updateDisableCache(value),
        ),
      ],
    );
  }

  Widget _disableFallback(BuildContext context, DnsController controller, DnsCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.dnsPageDisableFallback),
        Switch(
          value: state.dnsState.disableFallback,
          onChanged: (value) => controller.updateDisableFallback(value),
        ),
      ],
    );
  }

  Widget _disableFallbackIfMatch(
    BuildContext context,
    DnsController controller, DnsCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.dnsPageDisableFallbackIfMatch),
        Switch(
          value: state.dnsState.disableFallbackIfMatch,
          onChanged: (value) => controller.updateDisableFallbackIfMatch(value),
        ),
      ],
    );
  }

  Widget _useSystemHosts(BuildContext context, DnsController controller, DnsCubitState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.dnsPageUseSystemHosts),
        Switch(
          value: state.dnsState.useSystemHosts,
          onChanged: (value) => controller.updateUseSystemHosts(value),
        ),
      ],
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
}
