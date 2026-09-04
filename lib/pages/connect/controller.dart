import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/connect/view.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/platform_requirements.dart';
import 'package:onexray/service/connection/resolver.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/routing/custom_service.dart';
import 'package:onexray/service/routing/state.dart';

const _unchanged = Object();

class ConnectPageState {
  ConnectPageState({
    ConnectionConfiguration? configuration,
    this.connectionView = const ConnectionView(),
    List<CoreConfigData> servers = const [],
    List<CoreConfigData> raws = const [],
    List<RoutingProfileState> customRoutes = const [],
    List<SubscriptionData> sources = const [],
    this.expertView = false,
    this.ready = false,
    this.failed = false,
    this.pendingChange,
    this.trafficResetConfirming = false,
    this.trafficResetBusy = false,
    Set<int> deletingRawIds = const {},
    this.serverGroupingIndex = 0,
    this.activeServerGroupId,
    this.serverSearchQuery = '',
    Set<String> pendingServerActions = const {},
    Set<int> testingServerIds = const {},
    Set<int> favoritingServerIds = const {},
    this.selectingServers,
    Map<int, String> sourceErrors = const {},
    this.selectedExitId,
  }) : configuration = configuration ?? ConnectionConfiguration(),
       servers = List.unmodifiable(servers),
       raws = List.unmodifiable(raws),
       customRoutes = List.unmodifiable(customRoutes),
       sources = List.unmodifiable(sources),
       deletingRawIds = Set.unmodifiable(deletingRawIds),
       pendingServerActions = Set.unmodifiable(pendingServerActions),
       testingServerIds = Set.unmodifiable(testingServerIds),
       favoritingServerIds = Set.unmodifiable(favoritingServerIds),
       sourceErrors = Map.unmodifiable(sourceErrors);

  final ConnectionConfiguration configuration;
  final ConnectionView connectionView;
  final List<CoreConfigData> servers;
  final List<CoreConfigData> raws;
  final List<RoutingProfileState> customRoutes;
  final List<SubscriptionData> sources;
  final bool expertView;
  final bool ready;
  final bool failed;
  final String? pendingChange;
  final bool trafficResetConfirming;
  final bool trafficResetBusy;
  final Set<int> deletingRawIds;

  // ServersController extends ConnectController, so its page state lives in the
  // same Cubit state instead of introducing another notifier.
  final int serverGroupingIndex;
  final String? activeServerGroupId;
  final String serverSearchQuery;
  final Set<String> pendingServerActions;
  final Set<int> testingServerIds;
  final Set<int> favoritingServerIds;
  final ServerSelection? selectingServers;
  final Map<int, String> sourceErrors;
  final int? selectedExitId;

  ConnectPageState copyWith({
    ConnectionConfiguration? configuration,
    ConnectionView? connectionView,
    List<CoreConfigData>? servers,
    List<CoreConfigData>? raws,
    List<RoutingProfileState>? customRoutes,
    List<SubscriptionData>? sources,
    bool? expertView,
    bool? ready,
    bool? failed,
    Object? pendingChange = _unchanged,
    bool? trafficResetConfirming,
    bool? trafficResetBusy,
    Set<int>? deletingRawIds,
    int? serverGroupingIndex,
    Object? activeServerGroupId = _unchanged,
    String? serverSearchQuery,
    Set<String>? pendingServerActions,
    Set<int>? testingServerIds,
    Set<int>? favoritingServerIds,
    Object? selectingServers = _unchanged,
    Map<int, String>? sourceErrors,
    Object? selectedExitId = _unchanged,
  }) => ConnectPageState(
    configuration: configuration ?? this.configuration,
    connectionView: connectionView ?? this.connectionView,
    servers: servers ?? this.servers,
    raws: raws ?? this.raws,
    customRoutes: customRoutes ?? this.customRoutes,
    sources: sources ?? this.sources,
    expertView: expertView ?? this.expertView,
    ready: ready ?? this.ready,
    failed: failed ?? this.failed,
    pendingChange: identical(pendingChange, _unchanged)
        ? this.pendingChange
        : pendingChange as String?,
    trafficResetConfirming:
        trafficResetConfirming ?? this.trafficResetConfirming,
    trafficResetBusy: trafficResetBusy ?? this.trafficResetBusy,
    deletingRawIds: deletingRawIds ?? this.deletingRawIds,
    serverGroupingIndex: serverGroupingIndex ?? this.serverGroupingIndex,
    activeServerGroupId: identical(activeServerGroupId, _unchanged)
        ? this.activeServerGroupId
        : activeServerGroupId as String?,
    serverSearchQuery: serverSearchQuery ?? this.serverSearchQuery,
    pendingServerActions: pendingServerActions ?? this.pendingServerActions,
    testingServerIds: testingServerIds ?? this.testingServerIds,
    favoritingServerIds: favoritingServerIds ?? this.favoritingServerIds,
    selectingServers: identical(selectingServers, _unchanged)
        ? this.selectingServers
        : selectingServers as ServerSelection?,
    sourceErrors: sourceErrors ?? this.sourceErrors,
    selectedExitId: identical(selectedExitId, _unchanged)
        ? this.selectedExitId
        : selectedExitId as int?,
  );
}

class ConnectController extends PageCubit<ConnectPageState> {
  ConnectController({AppDatabase? database, ConnectionCoordinator? coordinator})
    : db = database ?? AppDatabase(),
      coordinator = coordinator ?? ConnectionCoordinator.instance,
      super(ConnectPageState()) {
    this.coordinator.state.addListener(_connectionChanged);
    _connectionChanged();
  }

  final AppDatabase db;
  final ConnectionCoordinator coordinator;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _viewInitialized = false;
  bool _pageVisible = false;
  bool _trafficDialogOpen = false;

  ConnectionConfiguration get configuration => state.configuration;
  set configuration(ConnectionConfiguration value) =>
      emit(state.copyWith(configuration: value));
  ConnectionView get connectionView => state.connectionView;
  List<CoreConfigData> get servers => state.servers;
  set servers(List<CoreConfigData> value) =>
      emit(state.copyWith(servers: value));
  List<CoreConfigData> get raws => state.raws;
  set raws(List<CoreConfigData> value) => emit(state.copyWith(raws: value));
  List<RoutingProfileState> get customRoutes => state.customRoutes;
  set customRoutes(List<RoutingProfileState> value) =>
      emit(state.copyWith(customRoutes: value));
  List<SubscriptionData> get sources => state.sources;
  set sources(List<SubscriptionData> value) =>
      emit(state.copyWith(sources: value));
  bool get expertView => state.expertView;
  set expertView(bool value) => emit(state.copyWith(expertView: value));
  bool get ready => state.ready;
  set ready(bool value) => emit(state.copyWith(ready: value));
  bool get failed => state.failed;
  set failed(bool value) => emit(state.copyWith(failed: value));
  String? get pendingChange => state.pendingChange;
  set pendingChange(String? value) =>
      emit(state.copyWith(pendingChange: value));
  Set<int> get deletingRawIds => state.deletingRawIds;

  void _connectionChanged() {
    if (isPageActive) {
      emit(state.copyWith(connectionView: coordinator.state.value));
    }
  }

  void setPageVisible(bool visible) {
    if (!isPageActive || _pageVisible == visible) return;
    _pageVisible = visible;
    _syncTrafficVisibility();
  }

  void _syncTrafficVisibility() => coordinator.setTrafficVisible(
    isPageActive && (_pageVisible || _trafficDialogOpen),
  );

  Future<void> initialize() async {
    failed = false;
    try {
      if (!isPageActive) return;
      configuration = await coordinator.configuration;
      if (!_viewInitialized) expertView = configuration.connection.expert;
      _viewInitialized = true;
      if (_subscriptions.isEmpty) {
        _subscriptions.add(
          db.connectionConfigDao.watch().listen((row) {
            configuration = ConnectionConfiguration.fromJson(
              jsonDecode(row.configurationJson) as Map<String, dynamic>,
            );
          }, onError: _readFailed),
        );
        _subscriptions.add(
          (db.select(db.coreConfig)
                ..where((row) => row.type.equals('outbound')))
              .watch()
              .listen((rows) {
                servers = rows;
              }, onError: _readFailed),
        );
        _subscriptions.add(
          db.coreConfigDao.allRawRowsWithDataStream.listen((rows) {
            raws = rows;
          }, onError: _readFailed),
        );
        _subscriptions.add(
          db.routingProfileDao.allRowsStream.listen((rows) {
            try {
              customRoutes = rows.map(CustomRoutingService.read).toList();
            } catch (error) {
              _readFailed(error);
              return;
            }
          }, onError: _readFailed),
        );
        _subscriptions.add(
          db.select(db.subscription).watch().listen((rows) {
            sources = rows;
          }, onError: _readFailed),
        );
      }
      ready = true;
    } catch (_) {
      failed = true;
    }
  }

  String serverName(CoreConfigData row) {
    try {
      return ResolvedServer.fromRow(row).name;
    } catch (_) {
      return row.name;
    }
  }

  String selectionTitle(AppLocalizations l10n) {
    final settings = configuration.connection;
    if (settings.trafficMode != TrafficMode.allVpn &&
        settings.selection.kind != SelectionKind.server) {
      final count = runningRoute?.entryCount ?? _configuredEntryCount(settings);
      if (count != null) {
        return count == 1
            ? l10n.prototypeAutomaticOneEntry
            : l10n.prototypeAutomaticEntries(count);
      }
    }
    return _selectionName(l10n, settings.selection);
  }

  String _selectionName(AppLocalizations l10n, ServerSelection selection) =>
      switch (selection.kind) {
        SelectionKind.automatic => l10n.prototypeAutomaticSelection,
        SelectionKind.region => selection.region ?? '',
        SelectionKind.source =>
          sources.where((row) => row.id == selection.id).firstOrNull?.name ??
              l10n.prototypeTemporarilyUnavailable,
        SelectionKind.server =>
          servers
                  .where((row) => row.id == selection.id)
                  .map(serverName)
                  .firstOrNull ??
              l10n.prototypeTemporarilyUnavailable,
      };

  int? _configuredEntryCount(ConnectionSettings settings) {
    if (settings.selection.kind == SelectionKind.server ||
        settings.trafficMode == TrafficMode.allVpn) {
      return 1;
    }
    if (settings.trafficMode == TrafficMode.smart) {
      return settings.smart.entryCount;
    }
    final profile = customRoutes
        .where((profile) => profile.id == settings.customId)
        .firstOrNull;
    return profile?.entryCount;
  }

  String? selectionDetail(AppLocalizations l10n) =>
      runningRoute?.path ??
      (configuration.connection.selection.kind == SelectionKind.server
          ? null
          : l10n.prototypeChooseBySpeedAvailability);

  // The runtime chooses the node identity; the badge shows that node's latest
  // successful probe, not a measurement of this session or a new selection.
  String? selectionHealth(AppLocalizations l10n) {
    final view = connectionView;
    if (view.phase != ConnectionPhase.connected) return null;
    final entries = view.runtime?.entries;
    if (entries == null || entries.isEmpty) return null;
    final id = entries.first.id;
    final row = servers.where((row) => row.id == id).firstOrNull;
    if (row == null ||
        row.delay <= 0 ||
        const {
          PingDelayConstants.unknown,
          PingDelayConstants.error,
          PingDelayConstants.timeout,
        }.contains(row.delay)) {
      return null;
    }
    return l10n.prototypeAvailableLatency(row.delay);
  }

  String homeMethodTitle(AppLocalizations l10n) =>
      configuration.connection.trafficMode == TrafficMode.smart
      ? l10n.prototypeSmartRoutingRecommended
      : methodTitle(l10n);

  int _ruleCount(RoutingProfileState profile) => profile.rules.length;

  String methodDescription(AppLocalizations l10n) {
    switch (configuration.connection.trafficMode) {
      case TrafficMode.smart:
        return l10n.prototypeSmartRoutingDescription;
      case TrafficMode.allVpn:
        return l10n.prototypeAllViaVpnDescription;
      case TrafficMode.custom:
        final row = customRoutes
            .where((row) => row.id == configuration.connection.customId)
            .firstOrNull;
        final count = row == null ? null : _ruleCount(row);
        return count == null
            ? l10n.prototypeCustomRoutingDescription
            : l10n.prototypeCustomRuleCount(count);
    }
  }

  /// Only the active runtime metadata describes the path in use. Later
  /// asset renames, probes and subscription updates cannot change these labels.
  ({int entryCount, String path})? get runningRoute {
    final view = connectionView;
    final runtime = view.runtime;
    if (view.phase != ConnectionPhase.connected ||
        runtime == null ||
        runtime.configuration.connection.expert) {
      return null;
    }
    final entries = runtime.entries;
    if (entries.isEmpty) return null;
    final names = entries.map((entry) => entry.name);
    final exit = runtime.finalExit;
    return (
      entryCount: entries.length,
      path: '${names.join(' + ')}${exit == null ? '' : ' → ${exit.name}'}',
    );
  }

  String methodTitle(AppLocalizations l10n) =>
      switch (configuration.connection.trafficMode) {
        TrafficMode.smart => l10n.prototypeSmartRouting,
        TrafficMode.allVpn => l10n.prototypeAllViaVpn,
        TrafficMode.custom =>
          customRoutes
                  .where((row) => row.id == configuration.connection.customId)
                  .firstOrNull
                  ?.name ??
              l10n.prototypeCustomRouting,
      };

  Future<void> connectionAction(BuildContext context) async {
    final view = connectionView;
    if (view.phase == ConnectionPhase.connected) {
      await run(context, coordinator.disconnect);
    } else if (view.busy) {
      coordinator.cancel();
    } else {
      if (expertView && !configuration.connection.expert) {
        if (raws.isEmpty) {
          await editRaw(context);
          return;
        }
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.prototypeChooseRawConfiguration,
        );
        return;
      }
      await run(context, () async {
        if (view.issue == 'permissionRequired' && view.permission != null) {
          await AppHostApi().requestPlatformPermission();
        }
        await coordinator.connect();
      });
    }
  }

  Future<void> toggleExpert(BuildContext context, bool value) async {
    if (connectionView.busy || pendingChange != null) return;
    if (!value && configuration.connection.expert) {
      if (!await change(context, {'expert': false})) return;
    }
    expertView = value;
  }

  Future<bool> change(
    BuildContext context,
    Map<String, dynamic> values, {
    Future<void> Function()? writeAssets,
    String? label,
  }) async {
    if (connectionView.busy || pendingChange != null) return false;
    pendingChange = values.containsKey('rawId')
        ? 'raw:${values['rawId']}'
        : values.containsKey('selection')
        ? 'selection'
        : values.containsKey('trafficMode')
        ? 'method'
        : 'expert';
    try {
      final l10n = AppLocalizations.of(context)!;
      final current = await coordinator.configuration;
      final next = ConnectionConfiguration(
        connection: ConnectionSettings.fromJson({
          ...current.connection.toJson(),
          ...values,
        }),
        policy: current.policy,
      );
      if (next.encode() == current.encode() && writeAssets == null) return true;
      if (!context.mounted) return false;
      final reconnect = connectionView.phase == ConnectionPhase.connected;
      if (reconnect &&
          !await showApplyAndReconnectDialog(
            context,
            label: label ?? _changeLabel(l10n, values, next.connection),
          )) {
        return false;
      }
      if (!context.mounted) return false;
      var success = false;
      await run(context, () async {
        await coordinator.apply(
          next,
          writeAssets: writeAssets,
          expectedConfiguration: current.encode(),
          allowReconnect: reconnect,
        );
        // A successful apply may legitimately commit Automatic instead of an
        // unavailable selection.
        success = true;
        configuration = await coordinator.configuration;
      });
      return success;
    } finally {
      pendingChange = null;
    }
  }

  String _changeLabel(
    AppLocalizations l,
    Map<String, dynamic> values,
    ConnectionSettings next,
  ) {
    if (next.expert) {
      return raws.where((row) => row.id == next.rawId).firstOrNull?.name ??
          'Raw JSON';
    }
    if (values.containsKey('selection')) {
      return _selectionName(l, next.selection);
    }
    return switch (next.trafficMode) {
      TrafficMode.smart => l.prototypeSmartRoutingRecommended,
      TrafficMode.allVpn => l.prototypeAllViaVpn,
      TrafficMode.custom =>
        customRoutes
                .where((row) => row.id == next.customId)
                .firstOrNull
                ?.name ??
            l.prototypeCustomRouting,
    };
  }

  Future<void> selectRaw(BuildContext context, int id) async {
    await change(context, {'expert': true, 'rawId': id});
  }

  Future<void> deleteRaw(BuildContext context, CoreConfigData row) async {
    if (connectionView.busy ||
        pendingChange != null ||
        deletingRawIds.contains(row.id)) {
      return;
    }
    emit(state.copyWith(deletingRawIds: {...deletingRawIds, row.id}));
    try {
      final expected = await coordinator.configuration;
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final active =
          expected.connection.expert && expected.connection.rawId == row.id;
      final connected = connectionView.phase == ConnectionPhase.connected;
      final disconnect = active && connected && servers.isEmpty;
      if (!await showDestructiveConfirmationDialog(
            context,
            title: l10n.prototypeDeleteRawQuestion,
            subtitle: row.name,
            warning: disconnect
                ? l10n.prototypeRawDeleteDisconnectNotice
                : active
                ? l10n.prototypeActiveRawDeleteNotice
                : l10n.prototypeRawDeleteNotice,
            confirmLabel: disconnect
                ? l10n.prototypeDeleteAndDisconnect
                : active && connected
                ? l10n.prototypeDeleteAndReconnect
                : l10n.prototypeDelete,
          ) ||
          !context.mounted) {
        return;
      }
      if (!context.mounted) return;
      await run(context, () async {
        final current = expected;
        await coordinator.apply(
          ConnectionConfiguration(
            connection: ConnectionSettings.fromJson({
              ...current.connection.toJson(),
              if (current.connection.rawId == row.id) ...{
                'expert': false,
                'rawId': null,
              },
            }),
            policy: current.policy,
          ),
          affectsRuntime: active && !disconnect,
          disconnect: disconnect,
          allowReconnect: connected,
          expectedConfiguration: expected.encode(),
          writeAssets: () async {
            final latest = await db.coreConfigDao.searchRow(row.id);
            if (latest == null ||
                latest.type != row.type ||
                latest.data != row.data) {
              throw StateError('Raw configuration changed before deletion');
            }
            await db.coreConfigDao.deleteRow(row);
          },
        );
        if (active) expertView = false;
      });
    } finally {
      emit(state.copyWith(deletingRawIds: {...deletingRawIds}..remove(row.id)));
    }
  }

  Widget _resetTrafficDialog(BuildContext context, {required bool busy}) {
    final l = AppLocalizations.of(context)!;
    return ConnectDialog(
      key: const ValueKey('reset-traffic'),
      title: l.prototypeResetTotals,
      subtitle: l.prototypeResetTrafficNotice,
      body: ConnectCallout(
        icon: LucideIcons.circleAlert,
        text: l.prototypeCannotUndo,
        warning: true,
      ),
      expandLastAction: false,
      actions: [
        ConnectDialogButton(
          label: l.prototypeCancel,
          secondary: true,
          onPressed: busy ? null : () => Navigator.of(context).pop(),
        ),
        ConnectDialogButton(
          label: l.prototypeResetTotals,
          destructive: true,
          icon: LucideIcons.rotateCcw,
          busy: busy,
          onPressed: busy
              ? null
              : () => unawaited(_resetTrafficInDialog(context)),
        ),
      ],
    );
  }

  Future<void> _resetTrafficInDialog(BuildContext context) async {
    if (state.trafficResetBusy) return;
    emit(state.copyWith(trafficResetBusy: true));
    final reset = await _clearTraffic(context);
    if (reset && context.mounted) Navigator.of(context).pop();
    emit(state.copyWith(trafficResetBusy: false));
  }

  Future<bool> _clearTraffic(BuildContext context) async {
    var reset = false;
    await run(context, () async {
      await coordinator.resetTraffic();
      reset = true;
    });
    if (reset && context.mounted) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.prototypeTrafficTotalsReset,
      );
    }
    return reset;
  }

  Future<void> addServers(BuildContext context) =>
      context.pushScoped(AppSecondaryDestination.serversImport);
  Future<void> editRaw(BuildContext context, [int? id]) =>
      context.pushScoped(AppSecondaryDestination.rawEditor, extra: id);
  void chooseServer(BuildContext context) =>
      context.goPrimaryRoot(AppPrimaryDestination.servers);

  Future<void> showRawActions(BuildContext context, CoreConfigData row) async {
    if (deletingRawIds.contains(row.id)) return;
    final edit = await showConnectDialog<bool>(context, (dialogContext) {
      final l = AppLocalizations.of(dialogContext)!;
      final palette = ColorManager.palette(dialogContext);
      return ConnectDialog(
        title: row.name,
        body: ListTileTheme(
          data: AppTheme.actionListTile,
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  LucideIcons.pencil,
                  color: palette.primary,
                  size: 20,
                ),
                title: Text(
                  l.prototypeEditRawJson,
                  style: AppTypography.dialogGroupTitle,
                ),
                trailing: const Icon(LucideIcons.chevronRightDir, size: 18),
                onTap: () => Navigator.of(dialogContext).pop(true),
              ),
              Divider(height: 1, color: palette.border),
              ListTile(
                enabled: !connectionView.busy,
                leading: Icon(
                  LucideIcons.trash2,
                  color: palette.destructive,
                  size: 20,
                ),
                title: Text(
                  l.prototypeDelete,
                  style: AppTypography.dialogGroupTitle.copyWith(
                    color: palette.destructive,
                  ),
                ),
                trailing: Icon(
                  LucideIcons.chevronRightDir,
                  color: palette.destructive,
                  size: 18,
                ),
                onTap: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
        ),
      );
    });
    if (!context.mounted || edit == null) return;
    if (edit) {
      await editRaw(context, row.id);
    } else {
      await deleteRaw(context, row);
    }
  }

  Future<void> chooseTrafficMethod(BuildContext context) async {
    final selected = await showConnectDialog<ConnectTrafficChoice>(
      context,
      (context) => ConnectTrafficMethodDialog(
        current: configuration.connection,
        customRoutes: [
          for (final profile in customRoutes)
            (
              id: profile.id!,
              name: profile.name,
              ruleCount: _ruleCount(profile),
            ),
        ],
      ),
    );
    if (selected != null && context.mounted) {
      if (selected.edit) {
        await context.pushScoped(
          selected.mode == TrafficMode.smart
              ? AppSecondaryDestination.smartRouting
              : AppSecondaryDestination.customRouting,
          extra: selected.id,
        );
        return;
      }
      await change(context, {
        'trafficMode': selected.mode.name,
        'customId': selected.id,
      });
    }
  }

  Future<void> showWhy(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final view = connectionView;
    final connected = view.phase == ConnectionPhase.connected;
    final runtime = connected ? view.runtime : null;
    final settings =
        runtime?.configuration.connection ?? configuration.connection;
    final names = connected
        ? (runtime?.entries ?? const <RuntimeNode>[])
              .map((entry) => entry.name)
              .toList()
        : _previewEntries(settings).map((row) => serverName(row)).toList();
    final entryNames = names.join(' + ');
    final exit = connected
        ? runtime?.finalExit?.name
        : servers
              .where((row) => row.id == settings.finalExitId)
              .map(serverName)
              .firstOrNull;
    final custom = customRoutes
        .where((row) => row.id == settings.customId)
        .firstOrNull;
    final methodReason = names.isEmpty
        ? l.prototypeNoAvailableEntries
        : switch (settings.trafficMode) {
            TrafficMode.smart =>
              exit == null
                  ? l.prototypeSmartConnectionReason(entryNames)
                  : l.prototypeSmartConnectionChainReason(entryNames, exit),
            TrafficMode.allVpn => l.prototypeAllVpnConnectionReason(entryNames),
            TrafficMode.custom =>
              custom == null
                  ? l.prototypeCustomConnectionReason
                  : l.prototypeNamedCustomConnectionReason(custom.name),
          };
    final selectionReason = names.isEmpty
        ? null
        : connected
        ? l.prototypeRunningEntriesReason(entryNames)
        : names.length > 1
        ? l.prototypeMultipleEntriesReason(names.length)
        : switch (settings.selection.kind) {
            SelectionKind.server => l.prototypeFixedEntryReason(entryNames),
            SelectionKind.region => l.prototypeRegionEntryReason(
              entryNames,
              settings.selection.region ?? '',
            ),
            _ => l.prototypeAutomaticEntryReason(entryNames),
          };
    await showConnectDialog<void>(
      context,
      (dialogContext) => ConnectDialog(
        title: l.prototypeWhyConnectionTitle,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
              child: Column(
                children: [
                  ConnectExplanation(
                    icon: LucideIcons.shieldCheck,
                    text: methodReason,
                  ),
                  if (selectionReason != null) ...[
                    const SizedBox(height: 15),
                    ConnectExplanation(
                      icon: LucideIcons.wifi,
                      text: selectionReason,
                    ),
                  ],
                ],
              ),
            ),
            ConnectCallout(
              icon: LucideIcons.lockKeyhole,
              text: l.prototypeNoAnalyticsLocalLogs,
            ),
          ],
        ),
        actions: [
          ConnectDialogButton(
            label: l.prototypeDone,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  /// Explain existing successful measurements without probing or selecting a
  /// runtime input. The actual connection still resolves through the coordinator.
  List<CoreConfigData> _previewEntries(ConnectionSettings settings) {
    final count = _configuredEntryCount(settings);
    if (count == null || settings.expert) return [];
    final rows =
        servers.where((row) {
          if (row.type != 'outbound' ||
              row.id <= 0 ||
              row.id == settings.finalExitId ||
              row.delay < 0 ||
              const {
                PingDelayConstants.unknown,
                PingDelayConstants.error,
                PingDelayConstants.timeout,
              }.contains(row.delay)) {
            return false;
          }
          final matches = switch (settings.selection.kind) {
            SelectionKind.automatic => true,
            SelectionKind.region =>
              row.countryCode?.toUpperCase() ==
                  settings.selection.region?.toUpperCase(),
            SelectionKind.source => row.subId == settings.selection.id,
            SelectionKind.server => row.id == settings.selection.id,
          };
          if (!matches) return false;
          try {
            ResolvedServer.fromRow(row);
            return true;
          } on FormatException {
            return false;
          }
        }).toList()..sort((a, b) {
          final delay = a.delay.compareTo(b.delay);
          return delay == 0 ? a.id.compareTo(b.id) : delay;
        });
    return rows.length < count ? [] : rows.take(count).toList();
  }

  Future<void> showTraffic(BuildContext context) async {
    if (!isPageActive || _trafficDialogOpen) return;
    _trafficDialogOpen = true;
    emit(
      state.copyWith(trafficResetConfirming: false, trafficResetBusy: false),
    );
    _syncTrafficVisibility();
    try {
      await showConnectDialog<void>(
        context,
        (dialogContext) => BlocBuilder<ConnectController, ConnectPageState>(
          bloc: this,
          builder: (_, state) {
            if (state.trafficResetConfirming) {
              return _resetTrafficDialog(
                dialogContext,
                busy: state.trafficResetBusy,
              );
            }
            final l = AppLocalizations.of(dialogContext)!;
            return ConnectDialog(
              title: l.prototypeTraffic,
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: TrafficReadout(
                  view: state.connectionView,
                  expandedGroups: true,
                ),
              ),
              actions: [
                ConnectDialogButton(
                  label: l.prototypeResetTotals,
                  secondary: true,
                  icon: LucideIcons.rotateCcw,
                  onPressed: () =>
                      emit(state.copyWith(trafficResetConfirming: true)),
                ),
                ConnectDialogButton(
                  label: l.prototypeDone,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      _trafficDialogOpen = false;
      if (isPageActive) {
        emit(
          state.copyWith(
            trafficResetConfirming: false,
            trafficResetBusy: false,
          ),
        );
        _syncTrafficVisibility();
      }
    }
  }

  Future<void> run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (connectionView.issue == 'cancelled') return;
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          error is ConnectionPlatformRequirementException
              ? AppLocalizations.of(context)!.prototypeChooseInterfaceNotice
              : error is ConnectionResolutionException
              ? AppLocalizations.of(context)!.prototypeNotEnoughServers
              : AppLocalizations.of(context)!.prototypeCheckNetwork,
        );
      }
    }
  }

  void _readFailed(Object error) {
    failed = true;
  }

  @override
  Future<void> disposePageResources() async {
    _syncTrafficVisibility();
    coordinator.state.removeListener(_connectionChanged);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
