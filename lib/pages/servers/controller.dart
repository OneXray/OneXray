import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/subscriptions/edit/params.dart';
import 'package:onexray/service/assets/server.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/routing/custom_template.dart';
import 'package:onexray/service/subscription/service.dart';

enum ServerGrouping { location, subscription }

enum ServerAction { edit, test, copy, share, delete }

enum SourceAction { update, test, edit, share, delete }

class ServerExitChoice {
  final int? id;
  const ServerExitChoice(this.id);
}

class ServerExitPickerParams {
  final int? selectedId;
  final Set<int> excludedIds;
  const ServerExitPickerParams({this.selectedId, this.excludedIds = const {}});
}

class ServerGroupParams {
  final ServersController controller;
  final String groupId;
  final bool picker;
  final ServerExitPickerParams? exitPicker;
  const ServerGroupParams(
    this.controller,
    this.groupId, {
    this.picker = false,
    this.exitPicker,
  });
}

class ServerGroup {
  final String id;
  final String name;
  final String? country;
  final SubscriptionData? source;
  final ServerSelection selection;
  final List<CoreConfigData> rows;
  final List<CoreConfigData> visibleRows;
  const ServerGroup({
    required this.id,
    required this.name,
    this.country,
    this.source,
    required this.selection,
    required this.rows,
    required this.visibleRows,
  });
}

class ServersController extends ConnectController {
  ServersController({
    super.database,
    super.coordinator,
    ServerAssetService? assets,
  }) {
    this.assets =
        assets ?? ServerAssetService(database: db, coordinator: coordinator);
  }
  late final ServerAssetService assets;
  final search = TextEditingController();
  ServerGrouping grouping = ServerGrouping.location;
  String? activeGroupId;
  bool actionBusy = false;
  bool _disposed = false;
  final Map<int, String> sourceErrors = {};

  bool get busy => actionBusy || coordinator.state.value.busy;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  void searchChanged(String value) => changed();
  void groupBy(ServerGrouping value) {
    grouping = value;
    activeGroupId = null;
    search.clear();
    changed();
  }

  String countryName(AppLocalizations l, String? code) =>
      switch (code?.toUpperCase()) {
        'CN' => l.prototypeMainlandChina,
        'RU' => l.prototypeRussia,
        'IR' => l.prototypeIran,
        'HK' => l.prototypeHongKong,
        'JP' => l.prototypeJapan,
        'SG' => l.prototypeSingapore,
        'KR' => l.prototypeSouthKorea,
        'US' => l.prototypeUnitedStates,
        'CA' => l.prototypeCanada,
        'DE' => l.prototypeGermany,
        'GB' => l.prototypeUnitedKingdom,
        'FR' => l.prototypeFrance,
        'IN' => l.prototypeIndia,
        'AU' => l.prototypeAustralia,
        'BR' => l.prototypeBrazil,
        'TR' => l.prototypeTurkey,
        null || '' => '—',
        _ => code!.toUpperCase(),
      };

  String sourceName(AppLocalizations l, CoreConfigData row) =>
      sources.where((source) => source.id == row.subId).firstOrNull?.name ??
      l.prototypeManualAdditions;

  int sourceCount(int id) => servers.where((row) => row.subId == id).length;

  bool matches(AppLocalizations l, CoreConfigData row) {
    final query = search.text.trim().toLowerCase();
    return query.isEmpty ||
        [
          serverName(row),
          countryName(l, row.countryCode),
          row.countryCode ?? '',
          sourceName(l, row),
        ].any((value) => value.toLowerCase().contains(query));
  }

  List<CoreConfigData> favorites(AppLocalizations l) =>
      servers.where((row) => row.favorite && matches(l, row)).toList();

  List<ServerGroup> groups(AppLocalizations l, {bool filter = true}) {
    final buckets = <String, List<CoreConfigData>>{};
    for (final row in servers) {
      final key = grouping == ServerGrouping.location
          ? (row.countryCode?.toUpperCase() ?? '')
          : '${row.subId}';
      buckets.putIfAbsent(key, () => []).add(row);
    }
    if (grouping == ServerGrouping.subscription) {
      for (final source in sources) {
        buckets.putIfAbsent('${source.id}', () => []);
      }
    }
    final result = <ServerGroup>[];
    for (final entry in buckets.entries) {
      final source = grouping == ServerGrouping.subscription
          ? sources.where((row) => '${row.id}' == entry.key).firstOrNull
          : null;
      final name = grouping == ServerGrouping.location
          ? countryName(l, entry.key)
          : source?.name ?? l.prototypeManualAdditions;
      final query = search.text.trim().toLowerCase();
      final wholeGroup = !filter || name.toLowerCase().contains(query);
      final visible = wholeGroup
          ? entry.value
          : entry.value.where((row) => matches(l, row)).toList();
      if (filter && query.isNotEmpty && visible.isEmpty && !wholeGroup) {
        continue;
      }
      result.add(
        ServerGroup(
          id: '${grouping.name}:${entry.key}',
          name: name,
          country: grouping == ServerGrouping.location ? entry.key : null,
          source: source,
          selection: grouping == ServerGrouping.location
              ? ServerSelection.region(entry.key)
              : ServerSelection.source(int.parse(entry.key)),
          rows: entry.value,
          visibleRows: visible,
        ),
      );
    }
    return result;
  }

  int entryCount(ServerSelection selection) {
    final connection = ConnectionSettings.fromJson({
      ...configuration.connection.toJson(),
      'expert': false,
      'selection': selection.toJson(),
    });
    int? customCount;
    if (connection.trafficMode == TrafficMode.custom) {
      final row = customRoutes
          .where((row) => row.id == connection.customId)
          .firstOrNull;
      if (row == null) return 0;
      try {
        customCount = CustomRoutingTemplate.parse(
          utf8.decode(base64Decode(row.data)),
        ).entryCount;
      } on FormatException {
        return 0;
      }
    }
    return connection.requiredEntries(customEntryCount: customCount);
  }

  bool canUse(ServerGroup group) {
    if (group.country == '') return false;
    final count = entryCount(group.selection);
    final finalExit = configuration.connection.trafficMode == TrafficMode.smart
        ? configuration.connection.smart.finalExitId
        : null;
    return count > 0 &&
        group.rows
                .where(
                  (row) =>
                      row.id != finalExit && ServerAssetService.selectable(row),
                )
                .length >=
            count;
  }

  bool selected(ServerSelection selection) =>
      !configuration.connection.expert &&
      jsonEncode(configuration.connection.selection.toJson()) ==
          jsonEncode(selection.toJson());

  bool canChoose(CoreConfigData row, {ServerExitPickerParams? exitPicker}) =>
      ServerAssetService.selectable(row) &&
      (exitPicker == null
          ? !(configuration.connection.trafficMode == TrafficMode.smart &&
                configuration.connection.smart.finalExitId == row.id)
          : !exitPicker.excludedIds.contains(row.id));

  bool exitConflict(CoreConfigData row, {ServerExitPickerParams? exitPicker}) =>
      exitPicker != null
      ? exitPicker.excludedIds.contains(row.id)
      : configuration.connection.trafficMode == TrafficMode.smart &&
            configuration.connection.smart.finalExitId == row.id;

  bool chosen(CoreConfigData row, {ServerExitPickerParams? exitPicker}) =>
      exitPicker == null
      ? selected(ServerSelection.server(row.id))
      : exitPicker.selectedId == row.id;

  String protocol(CoreConfigData row) => ServerAssetService.protocolLabel(row);

  void chooseRow(
    BuildContext context,
    CoreConfigData row, {
    bool picker = false,
    bool groupPage = false,
    ServerExitPickerParams? exitPicker,
  }) {
    if (!canChoose(row, exitPicker: exitPicker)) return;
    if (exitPicker != null) {
      chooseExit(context, row.id);
    } else {
      choose(
        context,
        ServerSelection.server(row.id),
        picker: picker,
        groupPage: groupPage,
      );
    }
  }

  Set<int> get runningEntries =>
      coordinator.state.value.phase == ConnectionPhase.connected
      ? {
          for (final entry
              in (coordinator.state.value.plan?.toJson()['entries'] as List?) ??
                  const [])
            (entry as Map)['id'] as int,
        }
      : {};

  String health(AppLocalizations l, CoreConfigData row) =>
      !ServerAssetService.measured(row)
      ? l.prototypeNotTested
      : !ServerAssetService.healthy(row)
      ? l.prototypeTemporarilyUnavailable
      : row.delay >= 300
      ? l.prototypeSlowLatency(row.delay)
      : l.prototypeAvailableLatency(row.delay);

  String summary(AppLocalizations l, ServerGroup group) {
    final healthy = group.rows.where(ServerAssetService.healthy).toList();
    final delays = healthy.map((row) => row.delay).toList()..sort();
    return delays.isEmpty
        ? l.prototypeServerCount(group.rows.length)
        : l.prototypeGroupAvailability(
            healthy.length,
            group.rows.length,
            delays.first,
          );
  }

  Future<void> browse(
    BuildContext context,
    ServerGroup group, {
    required bool mobile,
    bool picker = false,
    ServerExitPickerParams? exitPicker,
  }) async {
    activeGroupId = group.id;
    changed();
    if (mobile) {
      final choice = await context.pushScoped<Object>(
        AppSecondaryDestination.serverGroup,
        extra: ServerGroupParams(
          this,
          group.id,
          picker: picker,
          exitPicker: exitPicker,
        ),
      );
      if (context.mounted &&
          ((exitPicker != null && choice is ServerExitChoice) ||
              (picker && choice == true))) {
        Navigator.of(context).pop(choice);
      }
    }
  }

  Future<void> choose(
    BuildContext context,
    ServerSelection selection, {
    bool picker = false,
    bool groupPage = false,
  }) async {
    if (busy) return;
    if (await change(context, {
          'selection': selection.toJson(),
          'expert': false,
        }) &&
        context.mounted &&
        picker) {
      Navigator.of(context).pop(groupPage ? true : null);
    }
  }

  void chooseExit(BuildContext context, int? id) =>
      Navigator.of(context).pop(ServerExitChoice(id));

  Future<void> toggleFavorite(BuildContext context, CoreConfigData row) =>
      perform(context, () => assets.favorite(row.id, !row.favorite));

  Future<void> test(BuildContext context, Iterable<CoreConfigData> rows) =>
      perform(context, () async {
        await PingService().pingConfigIds(
          rows.map((row) => row.id).toList(),
          force: true,
        );
      });

  Future<void> serverAction(
    BuildContext context,
    CoreConfigData row,
    ServerAction action,
  ) async {
    if (busy) return;
    final l = AppLocalizations.of(context)!;
    switch (action) {
      case ServerAction.edit:
        await context.pushScoped(
          AppSecondaryDestination.serverEditor,
          extra: row.id,
        );
      case ServerAction.test:
        await test(context, [row]);
      case ServerAction.copy:
        await perform(context, () async {
          await assets.copyLocal(row, l.prototypeLocalCopy);
          if (context.mounted) {
            ContextAlert.showToast(context, l.prototypeLocalCopySaved);
          }
        });
      case ServerAction.share:
        await shareAsset(context, SharePageParams(ShareType.config, row.id));
      case ServerAction.delete:
        await remove(context, serverName(row), ids: {row.id});
    }
  }

  Future<void> sourceAction(
    BuildContext context,
    SubscriptionData source,
    SourceAction action,
  ) async {
    if (busy) return;
    switch (action) {
      case SourceAction.update:
        await perform(context, () async {
          final result = await SubscriptionService().refreshSubscriptionResult(
            source,
            false,
          );
          if (!context.mounted) return;
          final l = AppLocalizations.of(context)!;
          if (result.success) {
            sourceErrors.remove(source.id);
            ContextAlert.showToast(
              context,
              result.parseFailureCount == null
                  ? l.prototypeUsableNodes(result.count)
                  : l.prototypeSubscriptionImportResult(
                      source.name,
                      result.count,
                      result.parseFailureCount!,
                    ),
            );
          } else {
            sourceErrors[source.id] = l.prototypeSubscriptionUpdateFailed;
            ContextAlert.showToast(
              context,
              l.prototypeSubscriptionExistingNodesKept,
            );
          }
        });
      case SourceAction.test:
        await test(context, servers.where((row) => row.subId == source.id));
      case SourceAction.edit:
        await context.pushScoped(
          AppSecondaryDestination.subscriptionEdit,
          extra: SubscriptionEditParams(id: source.id),
        );
      case SourceAction.share:
        await shareAsset(
          context,
          SharePageParams(ShareType.subscription, source.id),
        );
      case SourceAction.delete:
        await remove(context, source.name, sourceId: source.id);
    }
  }

  Future<void> shareAsset(BuildContext context, SharePageParams params) async {
    final l = AppLocalizations.of(context)!;
    if (await ContextAlert.showConfirmDialog(
          context,
          title: params.type == ShareType.subscription
              ? l.prototypeShareSubscription
              : l.prototypeShareServer,
          content: params.type == ShareType.subscription
              ? l.prototypeSubscriptionShareWarning
              : l.prototypeServerShareWarning,
          confirmLabel: l.prototypeContinue,
        ) &&
        context.mounted) {
      await context.pushScoped(AppSecondaryDestination.share, extra: params);
    }
  }

  Future<void> remove(
    BuildContext context,
    String name, {
    Set<int> ids = const {},
    int? sourceId,
  }) async {
    await perform(context, () async {
      final preview = await assets.previewRemoval(ids: ids, sourceId: sourceId);
      if (!context.mounted) return;
      final l = AppLocalizations.of(context)!;
      if (!await ContextAlert.showConfirmDialog(
        context,
        title: sourceId == null
            ? l.prototypeDeleteServer
            : l.prototypeDeleteSource,
        content:
            '$name\n${l.prototypeServerCount(preview.ids.length)}\n\n${l.prototypeDeletedServerSelectionNotice}'
            '${preview.affectsRuntime && !preview.disconnect ? '\n\n${l.prototypeReconnectNotice}' : ''}',
        confirmLabel: preview.disconnect
            ? l.prototypeDeleteAndDisconnect
            : preview.affectsRuntime
            ? l.prototypeDeleteAndReconnect
            : l.prototypeDelete,
      )) {
        return;
      }
      await assets.remove(preview);
      if (context.mounted) {
        ContextAlert.showToast(context, l.prototypeNameRemoved(name));
      }
    });
  }

  Future<void> setAutomatic(
    BuildContext context,
    SubscriptionData source,
    bool value,
  ) => perform(context, () async {
    await SubscriptionService().setAutomaticUpdates(source.id, value);
  });

  Future<void> openSources(BuildContext context) =>
      context.pushScoped(AppSecondaryDestination.serverSources);

  Future<void> perform(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    if (busy) return;
    actionBusy = true;
    changed();
    try {
      await run(context, action);
    } finally {
      actionBusy = false;
      changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    search.dispose();
    super.dispose();
  }
}
