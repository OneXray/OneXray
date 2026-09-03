import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/pages/connect/view.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/background_task/service.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/connection/resolver.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/manager.dart';
import 'package:onexray/service/menu/short_cut/service.dart';
import 'package:onexray/service/share/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ConnectController extends ChangeNotifier {
  ConnectController({AppDatabase? database, ConnectionCoordinator? coordinator})
    : db = database ?? AppDatabase(),
      coordinator = coordinator ?? ConnectionCoordinator.instance;

  final AppDatabase db;
  final ConnectionCoordinator coordinator;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  ConnectionConfiguration configuration = ConnectionConfiguration();
  List<CoreConfigData> servers = [];
  List<CoreConfigData> raws = [];
  List<CustomRoutingProfileData> customRoutes = [];
  List<SubscriptionData> sources = [];
  bool expertView = false;
  bool ready = false;
  bool failed = false;
  bool _closed = false;
  bool _viewInitialized = false;
  bool _pageVisible = false;
  bool _trafficDialogOpen = false;

  void setPageVisible(bool visible) {
    if (_closed || _pageVisible == visible) return;
    _pageVisible = visible;
    _syncTrafficVisibility();
  }

  void _syncTrafficVisibility() => coordinator.setTrafficVisible(
    !_closed && (_pageVisible || _trafficDialogOpen),
  );

  Future<void> initialize(BuildContext context, {bool services = true}) async {
    failed = false;
    _notify();
    try {
      if (services) {
        ShortCutService().onConnectionFailure = () {
          if (context.mounted) context.goPrimaryRoot(AppPrimaryRoute.home);
        };
        ShareService().onIncomingShare = (text) async {
          if (context.mounted) {
            await context.pushScoped(
              AppSecondaryDestination.serversImport,
              extra: text,
            );
          }
        };
        await ServiceManager.serviceInit(context);
      }
      if (_closed) return;
      configuration = await coordinator.configuration;
      if (!_viewInitialized) expertView = configuration.connection.expert;
      _viewInitialized = true;
      if (_subscriptions.isEmpty) {
        _subscriptions.add(
          db.connectionStateDao.watch().listen((row) {
            configuration = ConnectionConfiguration.fromJson(
              jsonDecode(row.settingsJson) as Map<String, dynamic>,
            );
            _notify();
          }, onError: _readFailed),
        );
        _subscriptions.add(
          (db.select(db.coreConfig)
                ..where((row) => row.type.equals('outbound')))
              .watch()
              .listen((rows) {
                servers = rows;
                _notify();
              }, onError: _readFailed),
        );
        _subscriptions.add(
          db.coreConfigDao.allRawRowsWithDataStream.listen((rows) {
            raws = rows;
            _notify();
          }, onError: _readFailed),
        );
        _subscriptions.add(
          db.customRoutingProfilesDao.allRowsStream.listen((rows) {
            customRoutes = rows;
            _notify();
          }, onError: _readFailed),
        );
        _subscriptions.add(
          db.select(db.subscription).watch().listen((rows) {
            sources = rows;
            _notify();
          }, onError: _readFailed),
        );
      }
      ready = true;
      if (services) {
        BackgroundTaskService().init();
        unawaited(_checkUpdate());
      }
    } catch (_) {
      failed = true;
    }
    _notify();
  }

  Future<void> _checkUpdate() async {
    try {
      final service = AppUpdateService();
      if (!await service.shouldRunAutomaticCheck()) return;
      await service.recordAutomaticCheck();
      final result = await service.checkForUpdate();
      if (result.status == AppUpdateCheckStatus.upToDate) {
        AppEventBus.instance.updateAppUpdateInfo(null);
      } else if (result.updateInfo case final update?) {
        AppEventBus.instance.updateAppUpdateInfo(
          await service.shouldShowAutomaticReminder(update) ? update : null,
        );
      }
    } catch (_) {
      /* Update checks never block connection readiness. */
    }
  }

  String serverName(CoreConfigData row) {
    try {
      return ServerSnapshot.fromRow(row).name;
    } catch (_) {
      return row.name;
    }
  }

  String selectionTitle(AppLocalizations l10n) {
    final selection = configuration.connection.selection;
    final entryCount = runningRoute?.entryCount;
    return switch (selection.kind) {
      SelectionKind.automatic => switch (entryCount) {
        1 => l10n.prototypeAutomaticOneEntry,
        final count? => l10n.prototypeAutomaticEntries(count),
        null => l10n.prototypeAutomaticSelection,
      },
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
  }

  /// Only the confirmed running snapshot describes the path in use. Later
  /// asset renames, probes and subscription updates cannot change these labels.
  ({int entryCount, String path})? get runningRoute {
    final view = coordinator.state.value;
    final plan = view.plan;
    if (view.phase != ConnectionPhase.connected ||
        plan == null ||
        plan.configuration.connection.expert) {
      return null;
    }
    final json = plan.toJson();
    final entries = json['entries'] as List;
    if (entries.isEmpty) return null;
    final names = entries.map((entry) => (entry as Map)['name'] as String);
    final exit = json['finalExit'] as Map?;
    return (
      entryCount: entries.length,
      path: '${names.join(' + ')}${exit == null ? '' : ' → ${exit['name']}'}',
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
    final view = coordinator.state.value;
    if (view.phase == ConnectionPhase.connected) {
      await run(context, coordinator.disconnect);
    } else if (view.busy) {
      coordinator.cancel();
    } else {
      if (expertView && !configuration.connection.expert) {
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.prototypeAddRawJsonHint,
        );
        return;
      }
      await run(context, () async {
        if (view.permission != null) {
          await AppHostApi().requestPlatformPermission();
        }
        await coordinator.connect();
      });
    }
  }

  Future<void> toggleExpert(BuildContext context, bool value) async {
    if (coordinator.state.value.busy) return;
    if (!value && configuration.connection.expert) {
      if (!await change(context, {'expert': false})) return;
    }
    expertView = value;
    _notify();
  }

  Future<bool> change(
    BuildContext context,
    Map<String, dynamic> values, {
    Future<void> Function()? writeAssets,
  }) async {
    if (coordinator.state.value.busy) return false;
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
    final reconnect =
        coordinator.state.value.phase == ConnectionPhase.connected;
    if (reconnect &&
        !await ContextAlert.showConfirmDialog(
          context,
          title: l10n.prototypeApplyChange,
          content: l10n.prototypeReconnectNotice,
          confirmLabel: l10n.prototypeApplyAndReconnect,
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
      // Failed applies rethrow, including after restoration. A successful plan
      // may legitimately commit Automatic instead of an unavailable selection.
      success = true;
      configuration = await coordinator.configuration;
    });
    return success;
  }

  Future<void> selectRaw(BuildContext context, int id) async {
    await change(context, {'expert': true, 'rawId': id});
  }

  Future<void> deleteRaw(BuildContext context, CoreConfigData row) async {
    if (coordinator.state.value.busy) return;
    final expected = await coordinator.configuration;
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final active =
        expected.connection.expert && expected.connection.rawId == row.id;
    final connected =
        coordinator.state.value.phase == ConnectionPhase.connected;
    final disconnect = active && connected && servers.isEmpty;
    if (!await ContextAlert.showConfirmDialog(
          context,
          title: l10n.prototypeDeleteRawQuestion,
          content:
              '${row.name}\n\n${disconnect
                  ? l10n.prototypeRawDeleteDisconnectNotice
                  : active
                  ? l10n.prototypeActiveRawDeleteNotice
                  : l10n.prototypeRawDeleteNotice}',
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
      _notify();
    });
  }

  Future<void> resetTraffic(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (await ContextAlert.showConfirmDialog(
          context,
          title: l10n.prototypeResetTotals,
          content: l10n.prototypeResetTrafficNotice,
          confirmLabel: l10n.prototypeResetTotals,
        ) &&
        context.mounted) {
      await run(context, coordinator.resetTraffic);
    }
  }

  Future<void> addServers(BuildContext context) =>
      context.pushScoped(AppSecondaryDestination.serversImport);
  Future<void> editRaw(BuildContext context, [int? id]) =>
      context.pushScoped(AppSecondaryDestination.rawEditor, extra: id);
  Future<void> chooseServer(BuildContext context) =>
      context.pushScoped(AppSecondaryDestination.serverPicker);

  Future<void> selectServer(
    BuildContext context,
    ServerSelection selection, {
    bool close = false,
  }) async {
    if (await change(context, {
          'selection': selection.toJson(),
          'expert': false,
        }) &&
        context.mounted &&
        close) {
      Navigator.pop(context);
    }
  }

  Future<void> chooseTrafficMethod(BuildContext context) async {
    final selected =
        await showChoiceDialog<({TrafficMode mode, int? id, bool edit})>(
          context,
          (context) {
            final l = AppLocalizations.of(context)!;
            final current = configuration.connection;
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.prototypeTrafficMethod,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(l.prototypeSmartRoutingRecommended),
                      subtitle: Text(l.prototypeSmartRoutingDescription),
                      selected: current.trafficMode == TrafficMode.smart,
                      trailing: IconButton(
                        tooltip: l.prototypeEdit,
                        icon: const Icon(LucideIcons.pencil),
                        onPressed: () => Navigator.pop(context, (
                          mode: TrafficMode.smart,
                          id: null,
                          edit: true,
                        )),
                      ),
                      onTap: () => Navigator.pop(context, (
                        mode: TrafficMode.smart,
                        id: null,
                        edit: false,
                      )),
                    ),
                    ListTile(
                      title: Text(l.prototypeAllViaVpn),
                      subtitle: Text(l.prototypeAllViaVpnDescription),
                      selected: current.trafficMode == TrafficMode.allVpn,
                      onTap: () => Navigator.pop(context, (
                        mode: TrafficMode.allVpn,
                        id: null,
                        edit: false,
                      )),
                    ),
                    for (final row in customRoutes)
                      ListTile(
                        title: Text(row.name),
                        subtitle: Text(l.prototypeCustomRoutingDescription),
                        selected:
                            current.trafficMode == TrafficMode.custom &&
                            current.customId == row.id,
                        trailing: IconButton(
                          tooltip: l.prototypeEdit,
                          icon: const Icon(LucideIcons.pencil),
                          onPressed: () => Navigator.pop(context, (
                            mode: TrafficMode.custom,
                            id: row.id,
                            edit: true,
                          )),
                        ),
                        onTap: () => Navigator.pop(context, (
                          mode: TrafficMode.custom,
                          id: row.id,
                          edit: false,
                        )),
                      ),
                    if (customRoutes.length < 3)
                      ListTile(
                        leading: const Icon(LucideIcons.plus),
                        title: Text(l.prototypeAdd),
                        subtitle: Text(l.prototypeCustomRouting),
                        onTap: () => Navigator.pop(context, (
                          mode: TrafficMode.custom,
                          id: null,
                          edit: true,
                        )),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.prototypeCancel),
                    ),
                  ],
                ),
              ),
            );
          },
        );
    if (selected != null && context.mounted) {
      if (selected.edit) {
        await context.pushScoped(
          selected.mode == TrafficMode.smart
              ? AppSecondaryDestination.smartRouting
              : AppSecondaryDestination.customRouting,
          extra: selected.id,
        );
        if (context.mounted) await chooseTrafficMethod(context);
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
    final plan = coordinator.state.value.plan?.toJson();
    final entries = (plan?['entries'] as List?) ?? [];
    await ContextAlert.showOKDialog(
      context,
      l.prototypeWhyThisConnection,
      [
        selectionTitle(l),
        methodTitle(l),
        if (entries.isNotEmpty)
          entries.map((entry) => (entry as Map)['name']).join(' + '),
        if (plan?['finalExit'] is Map)
          '→ ${(plan!['finalExit'] as Map)['name']}',
        switch (configuration.connection.trafficMode) {
          TrafficMode.smart => l.prototypeSmartRoutingDescription,
          TrafficMode.allVpn => l.prototypeAllViaVpnDescription,
          TrafficMode.custom => l.prototypeCustomRoutingDescription,
        },
      ].join('\n\n'),
    );
  }

  Future<void> showTraffic(BuildContext context) async {
    if (_closed || _trafficDialogOpen) return;
    _trafficDialogOpen = true;
    _syncTrafficVisibility();
    try {
      await showChoiceDialog<void>(
        context,
        (dialogContext) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(dialogContext)!.prototypeTraffic,
                  style: Theme.of(dialogContext).textTheme.titleLarge,
                ),
                ValueListenableBuilder<ConnectionView>(
                  valueListenable: coordinator.state,
                  builder: (_, view, _) => TrafficReadout(view: view),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => resetTraffic(dialogContext),
                      child: Text(
                        AppLocalizations.of(dialogContext)!
                            .prototypeResetTotals,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        AppLocalizations.of(dialogContext)!.prototypeClose,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _trafficDialogOpen = false;
      if (!_closed) _syncTrafficVisibility();
    }
  }

  Future<void> run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (coordinator.state.value.issue == 'cancelled') return;
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          error is ConnectionResolutionException
              ? AppLocalizations.of(context)!.prototypeNotEnoughServers
              : AppLocalizations.of(context)!.prototypeCheckNetwork,
        );
      }
    }
  }

  void _readFailed(Object error) {
    failed = true;
    _notify();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _syncTrafficVisibility();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
