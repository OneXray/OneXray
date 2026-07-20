import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/xray/profile/dns_server_state.dart';
import 'package:onexray/service/xray/profile/dns_state.dart';

class DnsView extends StatelessWidget {
  final DnsState state;
  final TextEditingController clientIpController;
  final TextEditingController serveExpiredTTLController;
  final VoidCallback onEditHosts;
  final VoidCallback onAppendServer;
  final ReorderCallback onSortServer;
  final ValueChanged<int> onEditServer;
  final ValueChanged<int> onDeleteServer;
  final ValueChanged<bool> onUpdateDisableCache;
  final ValueChanged<bool> onUpdateServeStale;
  final ValueChanged<bool> onUpdateDisableFallback;
  final ValueChanged<bool> onUpdateDisableFallbackIfMatch;
  final ValueChanged<bool> onUpdateEnableParallelQuery;
  final ValueChanged<bool> onUpdateUseSystemHosts;

  const DnsView({
    super.key,
    required this.state,
    required this.clientIpController,
    required this.serveExpiredTTLController,
    required this.onEditHosts,
    required this.onAppendServer,
    required this.onSortServer,
    required this.onEditServer,
    required this.onDeleteServer,
    required this.onUpdateDisableCache,
    required this.onUpdateServeStale,
    required this.onUpdateDisableFallback,
    required this.onUpdateDisableFallbackIfMatch,
    required this.onUpdateEnableParallelQuery,
    required this.onUpdateUseSystemHosts,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsPageScroll(
      child: Column(
        children: [
          SettingsPageIntro(title: l10n.dnsPageTitle),
          SettingsResponsiveColumns(
            firstFlex: 5,
            secondFlex: 5,
            first: [_hostsSection(context), _serversSection(context)],
            second: [_policySection(context)],
          ),
        ],
      ),
    );
  }

  Widget _hostsSection(BuildContext context) {
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsPageSectionHosts,
      children: [
        NavigationSettingRow(
          leading: const Icon(LucideIcons.list),
          title: AppLocalizations.of(context)!.dnsPageHosts,
          onTap: onEditHosts,
        ),
      ],
    );
  }

  Widget _serversSection(BuildContext context) {
    final serverViews = state.servers
        .mapIndexed((index, server) => _serverCell(context, server, index))
        .toList();
    return SettingSection(
      title: AppLocalizations.of(context)!.dnsPageSectionServers,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.database),
          title: AppLocalizations.of(context)!.dnsPageServers,
          trailing: IconButton(
            onPressed: onAppendServer,
            icon: const Icon(LucideIcons.plus),
          ),
        ),
        if (serverViews.isNotEmpty)
          ReorderableListView(
            buildDefaultDragHandles: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: onSortServer,
            children: serverViews,
          ),
      ],
    );
  }

  Widget _serverCell(
    BuildContext context,
    DnsServerState server,
    int serverIndex,
  ) {
    return ReorderableDelayedDragStartListener(
      key: Key("$serverIndex"),
      index: serverIndex,
      child: DataListRow(
        onTap: () => onEditServer(serverIndex),
        title: server.address,
        trailing: ActionCluster(
          children: [
            AppMenuButton<IconMenuId>(
              icon: LucideIcons.ellipsis,
              entries: iconMenuEntries([IconMenuId.delete]),
              onSelected: (_) => onDeleteServer(serverIndex),
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

  Widget _policySection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.dnsPageSectionPolicy,
      children: [
        SettingRow(
          leading: const Icon(LucideIcons.tag),
          title: l10n.dnsPageTag,
          value: state.tag,
        ),
        TextFieldSettingRow(
          controller: clientIpController,
          label: l10n.dnsPageClientIp,
          hintText: l10n.dnsPageClientIpExample,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.databaseZap),
          title: l10n.dnsPageDisableCache,
          value: state.disableCache,
          onChanged: onUpdateDisableCache,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.clock),
          title: l10n.dnsPageServeStale,
          value: state.serveStale,
          onChanged: onUpdateServeStale,
        ),
        TextFieldSettingRow(
          controller: serveExpiredTTLController,
          label: l10n.dnsPageServeExpiredTTL,
          hintText: l10n.dnsPageServeExpiredTTLExample,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.rotateCcw),
          title: l10n.dnsPageDisableFallback,
          value: state.disableFallback,
          onChanged: onUpdateDisableFallback,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.filter),
          title: l10n.dnsPageDisableFallbackIfMatch,
          value: state.disableFallbackIfMatch,
          onChanged: onUpdateDisableFallbackIfMatch,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.gitBranch),
          title: l10n.dnsPageEnableParallelQuery,
          value: state.enableParallelQuery,
          onChanged: onUpdateEnableParallelQuery,
        ),
        SwitchSettingRow(
          leading: const Icon(LucideIcons.fileCode),
          title: l10n.dnsPageUseSystemHosts,
          value: state.useSystemHosts,
          onChanged: onUpdateUseSystemHosts,
        ),
      ],
    );
  }
}
