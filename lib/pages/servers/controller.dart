import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/servers/menus.dart';
import 'package:onexray/pages/servers/sources.dart';
import 'package:onexray/pages/subscriptions/edit/params.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/service/assets/server.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/ping/service.dart';
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
  const ServerGroupParams(this.controller, this.groupId);
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
    search.addListener(_searchChanged);
  }
  late final ServerAssetService assets;
  final search = TextEditingController();
  ServerGrouping get grouping =>
      ServerGrouping.values[state.serverGroupingIndex];
  set grouping(ServerGrouping value) =>
      emit(state.copyWith(serverGroupingIndex: value.index));
  String? get activeGroupId => state.activeServerGroupId;
  set activeGroupId(String? value) =>
      emit(state.copyWith(activeServerGroupId: value));
  Set<String> get _pending => state.pendingServerActions;
  Set<int> get testingIds => state.testingServerIds;
  Set<int> get favoritingIds => state.favoritingServerIds;
  ServerSelection? get selecting => state.selectingServers;
  set selecting(ServerSelection? value) =>
      emit(state.copyWith(selectingServers: value));
  Map<int, String> get sourceErrors => state.sourceErrors;

  void setSourceError(int id, String? error) {
    final next = {...sourceErrors};
    if (error == null) {
      next.remove(id);
    } else {
      next[id] = error;
    }
    emit(state.copyWith(sourceErrors: next));
  }

  bool get busy =>
      selecting != null || pendingChange != null || connectionView.busy;
  bool serverBusy(CoreConfigData row) =>
      _pending.contains('server:${row.id}') ||
      _pending.contains('source:${row.subId}');
  bool sourceBusy(int id) =>
      _pending.contains('source:$id') ||
      servers.any(
        (row) => row.subId == id && _pending.contains('server:${row.id}'),
      );
  bool testing(Iterable<CoreConfigData> rows) =>
      rows.any((row) => testingIds.contains(row.id));
  bool selectingGroup(ServerSelection value) =>
      selecting != null &&
      jsonEncode(selecting!.toJson()) == jsonEncode(value.toJson());
  void changed() => emit(state.copyWith(serverSearchQuery: search.text));

  void _searchChanged() => searchChanged(search.text);
  void searchChanged(String value) {
    if (value != state.serverSearchQuery) {
      emit(state.copyWith(serverSearchQuery: value));
    }
  }

  void groupBy(ServerGrouping value) {
    grouping = value;
    activeGroupId = null;
    search.clear();
    changed();
  }

  String countryName(AppLocalizations l, String? code) {
    final normalized = code?.toUpperCase();
    return normalized == null || normalized.isEmpty
        ? '—'
        : l.countryRegionName(normalized);
  }

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
      final profile = customRoutes
          .where((profile) => profile.id == connection.customId)
          .firstOrNull;
      if (profile == null) return 0;
      customCount = profile.entryCount;
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

  // Display only: running identities come from the active runtime. Offline
  // previews use existing successful probes, never start a probe or select VPN.
  ({List<String> names, CoreConfigData? first}) get _displaySelection {
    final settings = configuration.connection;
    if (settings.expert) return (names: [], first: null);
    final view = connectionView;
    if (view.phase == ConnectionPhase.connected) {
      final runtime = view.runtime;
      if (runtime == null || runtime.configuration.connection.expert) {
        return (names: [], first: null);
      }
      final entries = runtime.entries;
      return (
        names: entries.map((entry) => entry.name).toList(),
        first: servers
            .where((row) => row.id == entries.firstOrNull?.id)
            .firstOrNull,
      );
    }
    final selection = settings.selection;
    final count = entryCount(selection);
    final rows =
        servers.where((row) {
          if (row.id == settings.finalExitId ||
              !ServerAssetService.healthy(row) ||
              !ServerAssetService.selectable(row)) {
            return false;
          }
          return switch (selection.kind) {
            SelectionKind.automatic => true,
            SelectionKind.region =>
              row.countryCode?.toUpperCase() == selection.region?.toUpperCase(),
            SelectionKind.source => row.subId == selection.id,
            SelectionKind.server => row.id == selection.id,
          };
        }).toList()..sort((a, b) {
          final delay = a.delay.compareTo(b.delay);
          return delay == 0 ? a.id.compareTo(b.id) : delay;
        });
    if (count <= 0 || rows.length < count) return (names: [], first: null);
    return (
      names: rows.take(count).map(serverName).toList(),
      first: rows.first,
    );
  }

  String? automaticResult(AppLocalizations l) {
    if (!selected(const ServerSelection.automatic())) return null;
    final display = _displaySelection;
    if (display.names.isEmpty) return null;
    final row = display.first;
    return l.prototypeCurrentServerLatency(
      display.names.first,
      row != null && ServerAssetService.healthy(row) ? row.delay : '—',
    );
  }

  ({String title, String detail})? currentSelectionSummary(AppLocalizations l) {
    final settings = configuration.connection;
    final selection = settings.selection;
    if (settings.expert || selection.kind == SelectionKind.automatic) {
      return null;
    }
    final display = _displaySelection;
    final row =
        display.first ??
        servers.where((row) => row.id == selection.id).firstOrNull;
    final title = switch (selection.kind) {
      SelectionKind.automatic => l.prototypeAutomaticSelection,
      SelectionKind.region => countryName(l, selection.region),
      SelectionKind.source =>
        selection.id == 0
            ? l.prototypeManualAdditions
            : sources
                      .where((source) => source.id == selection.id)
                      .firstOrNull
                      ?.name ??
                  l.prototypeTemporarilyUnavailable,
      SelectionKind.server =>
        display.names.firstOrNull ??
            (row == null ? l.prototypeTemporarilyUnavailable : serverName(row)),
    };
    return (
      title: title,
      detail: selection.kind == SelectionKind.server
          ? row == null
                ? ''
                : '${countryName(l, row.countryCode)} · ${sourceName(l, row)}'
          : '${l.prototypeAutomaticSelection}${display.names.isEmpty ? '' : ' · ${display.names.join(' + ')}'}',
    );
  }

  String? get currentGroupId {
    final selection = configuration.connection.selection;
    final first = _displaySelection.first;
    if (grouping == ServerGrouping.location) {
      final code = selection.kind == SelectionKind.region
          ? selection.region
          : first?.countryCode;
      return code == null ? null : 'location:${code.toUpperCase()}';
    }
    final id = selection.kind == SelectionKind.source
        ? selection.id
        : first?.subId;
    return id == null ? null : 'subscription:$id';
  }

  bool canChoose(CoreConfigData row, {ServerExitPickerParams? exitPicker}) =>
      ServerAssetService.selectable(row) &&
      (exitPicker == null
          ? !(configuration.connection.trafficMode == TrafficMode.smart &&
                configuration.connection.smart.finalExitId == row.id)
          : !exitPicker.excludedIds.contains(row.id));

  bool exitConflict(CoreConfigData row) =>
      configuration.connection.trafficMode == TrafficMode.smart &&
      configuration.connection.smart.finalExitId == row.id;

  bool chosen(CoreConfigData row) => selected(ServerSelection.server(row.id));

  String protocol(CoreConfigData row) => ServerAssetService.protocolLabel(row);

  void chooseRow(BuildContext context, CoreConfigData row) {
    if (!canChoose(row)) return;
    choose(context, ServerSelection.server(row.id));
  }

  Set<int> get runningEntries =>
      connectionView.phase == ConnectionPhase.connected
      ? {
          for (final entry
              in connectionView.runtime?.entries ?? const <RuntimeNode>[])
            entry.id,
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
    final available = group.rows.where(ServerAssetService.selectable).length;
    final delays =
        group.rows
            .where(ServerAssetService.selectable)
            .where(ServerAssetService.healthy)
            .map((row) => row.delay)
            .toList()
          ..sort();
    return l.prototypeGroupAvailability(
      available,
      group.rows.length,
      delays.firstOrNull ?? '—',
    );
  }

  String? sourceCheckedLabel(
    AppLocalizations l,
    DateTime timestamp, {
    DateTime? now,
  }) {
    final checked = timestamp.toLocal();
    final reference = (now ?? DateTime.now()).toLocal();
    final elapsed = reference.difference(checked);
    if (elapsed.isNegative || elapsed.inMinutes < 1) {
      return l.prototypeCheckedJustNow;
    }
    if (DateUtils.isSameDay(checked, reference)) {
      return l.prototypeCheckedToday;
    }
    return null;
  }

  Future<void> browse(
    BuildContext context,
    ServerGroup group, {
    required bool mobile,
  }) async {
    activeGroupId = group.id;
    changed();
    if (mobile) {
      await context.pushScoped(
        AppSecondaryDestination.serverGroup,
        extra: ServerGroupParams(this, group.id),
      );
    }
  }

  Future<void> choose(BuildContext context, ServerSelection selection) async {
    if (busy) return;
    selecting = selection;
    changed();
    try {
      await change(context, {'selection': selection.toJson(), 'expert': false});
    } finally {
      selecting = null;
      changed();
    }
  }

  void chooseExit(BuildContext context, int? id) =>
      Navigator.of(context).pop(ServerExitChoice(id));

  Future<void> toggleFavorite(BuildContext context, CoreConfigData row) =>
      perform(context, () async {
        emit(state.copyWith(favoritingServerIds: {...favoritingIds, row.id}));
        try {
          await assets.favorite(row.id, !row.favorite);
        } finally {
          emit(
            state.copyWith(
              favoritingServerIds: {...favoritingIds}..remove(row.id),
            ),
          );
        }
      }, ids: {row.id});

  Future<void> test(BuildContext context, Iterable<CoreConfigData> rows) async {
    final ids = rows.map((row) => row.id).toSet();
    if (ids.isEmpty) return;
    await perform(context, () async {
      emit(state.copyWith(testingServerIds: {...testingIds, ...ids}));
      try {
        await PingService().pingConfigIds(ids.toList(), force: true);
      } finally {
        emit(state.copyWith(testingServerIds: {...testingIds}..removeAll(ids)));
      }
    }, ids: ids);
  }

  Future<void> serverAction(
    BuildContext context,
    CoreConfigData row,
    ServerAction action,
  ) async {
    if (serverBusy(row)) return;
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
        }, ids: {row.id});
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
    if (sourceBusy(source.id)) return;
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
            setSourceError(source.id, null);
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
            setSourceError(source.id, l.prototypeSubscriptionUpdateFailed);
            final navigator = Navigator.of(context);
            final closeSources = ModalRoute.of(context) is PopupRoute;
            final dialogContext = navigator.context;
            if (closeSources) navigator.pop();
            await showAppDialog<void>(
              dialogContext,
              (_) => SourceUpdateErrorDialog(
                sourceName: source.name,
                failedCount: result.parseFailureCount ?? 0,
              ),
            );
          }
        }, sourceId: source.id);
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

  Future<void> shareAsset(BuildContext context, SharePageParams params) =>
      context.pushScoped(AppSecondaryDestination.share, extra: params);

  Future<void> remove(
    BuildContext context,
    String name, {
    Set<int> ids = const {},
    int? sourceId,
  }) async {
    await perform(
      context,
      () async {
        final preview = await assets.previewRemoval(
          ids: ids,
          sourceId: sourceId,
        );
        if (!context.mounted) return;
        final l = AppLocalizations.of(context)!;
        final reconnect = preview.affectsRuntime && !preview.disconnect;
        if (!await showDestructiveConfirmationDialog(
          context,
          title: sourceId == null
              ? l.prototypeDeleteServer
              : l.prototypeDeleteSource,
          subtitle: name,
          warning:
              '${sourceId == null ? l.prototypeDeletedServerSelectionNotice : l.prototypeSourceDeleteWarning(preview.ids.length)}'
              '${reconnect ? '\n\n${l.prototypeReconnectNotice}' : ''}',
          confirmLabel: preview.disconnect
              ? l.prototypeDeleteAndDisconnect
              : reconnect
              ? l.prototypeDeleteAndReconnect
              : l.prototypeDelete,
        )) {
          return;
        }
        await assets.remove(preview);
        if (context.mounted) {
          ContextAlert.showToast(context, l.prototypeNameRemoved(name));
        }
      },
      ids: ids,
      sourceId: sourceId,
    );
  }

  Future<void> openSources(BuildContext context) async {
    final source = await showAppDialog<SubscriptionData>(
      context,
      (_) => ServerSourcesDialog(controller: this),
      desktopMaxWidth: AppLayout.sourcesDialogWidth,
    );
    if (source == null || !context.mounted || !isPageActive) return;
    final action = await showSourceActionsMenu(
      context,
      name: source.name,
      count: sourceCount(source.id),
    );
    if (action != null && context.mounted && isPageActive) {
      await sourceAction(context, source, action);
    }
  }

  Future<void> openServerHelp(BuildContext context) async {
    final add = await showAppDialog<bool>(
      context,
      (_) => ServerHelpDialog(canScanQr: AppPlatform.isMobile),
    );
    if (add == true && context.mounted && isPageActive) {
      await addServers(context);
    }
  }

  Future<void> perform(
    BuildContext context,
    Future<void> Function() action, {
    Set<int> ids = const {},
    int? sourceId,
  }) async {
    final keys = <String>{
      for (final id in ids) 'server:$id',
      if (sourceId != null) 'source:$sourceId',
    };
    if (keys.any(_pending.contains) ||
        (sourceId != null && sourceBusy(sourceId)) ||
        servers.any(
          (row) =>
              ids.contains(row.id) && _pending.contains('source:${row.subId}'),
        )) {
      return;
    }
    emit(state.copyWith(pendingServerActions: {..._pending, ...keys}));
    try {
      await run(context, action);
    } finally {
      emit(
        state.copyWith(pendingServerActions: {..._pending}..removeAll(keys)),
      );
    }
  }

  @override
  Future<void> disposePageResources() async {
    search.removeListener(_searchChanged);
    search.dispose();
    await super.disposePageResources();
  }
}

/// Final-exit selection is a local draft; only Done returns a choice.
class ServerExitPickerController extends ServersController {
  ServerExitPickerController(this.params, {super.database, super.coordinator}) {
    selectedId = params.selectedId;
  }

  final ServerExitPickerParams params;
  int? get selectedId => state.selectedExitId;
  set selectedId(int? value) => emit(state.copyWith(selectedExitId: value));

  @override
  void groupBy(ServerGrouping value) {
    grouping = value;
    changed();
  }

  List<ServerGroup> selectionGroups(AppLocalizations l) =>
      groups(l).where((group) => group.visibleRows.isNotEmpty).toList();

  bool canSelect(CoreConfigData row) => canChoose(row, exitPicker: params);

  void selectDraft(CoreConfigData? row) {
    if (busy || !ready || (row != null && !canSelect(row))) return;
    selectedId = row?.id;
    changed();
  }

  String exitRowDetail(AppLocalizations l, CoreConfigData row) {
    if (params.excludedIds.contains(row.id)) return l.prototypeEntryServer;
    if (!canSelect(row)) return l.prototypeTemporarilyUnavailable;
    final context = grouping == ServerGrouping.location
        ? sourceName(l, row)
        : countryName(l, row.countryCode);
    return '$context · ${health(l, row)}';
  }

  bool get canFinish =>
      ready &&
      !failed &&
      !busy &&
      (selectedId == null ||
          servers.any((row) => row.id == selectedId && canSelect(row)));

  void complete(BuildContext context) {
    if (canFinish) chooseExit(context, selectedId);
  }
}
