import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/connect/view.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/theme.dart';
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
import 'package:onexray/service/routing/custom_service.dart';
import 'package:onexray/service/routing/state.dart';
import 'package:onexray/service/share/service.dart';

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
  List<RoutingProfileState> customRoutes = [];
  List<SubscriptionData> sources = [];
  bool expertView = false;
  bool ready = false;
  bool failed = false;
  bool _closed = false;
  bool _viewInitialized = false;
  bool _pageVisible = false;
  bool _trafficDialogOpen = false;
  String? pendingChange;
  final Set<int> deletingRawIds = {};

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
          db.routingProfileDao.allRowsStream.listen((rows) {
            try {
              customRoutes = rows.map(CustomRoutingService.read).toList();
            } catch (error) {
              _readFailed(error);
              return;
            }
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

  // The plan chooses the node identity; the badge shows that node's latest
  // successful probe, not a measurement of this session or a new selection.
  String? selectionHealth(AppLocalizations l10n) {
    final view = coordinator.state.value;
    if (view.phase != ConnectionPhase.connected) return null;
    final entries = view.plan?.toJson()['entries'] as List?;
    if (entries == null || entries.isEmpty) return null;
    final id = (entries.first as Map)['id'];
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
        if (view.permission != null) {
          await AppHostApi().requestPlatformPermission();
        }
        await coordinator.connect();
      });
    }
  }

  Future<void> toggleExpert(BuildContext context, bool value) async {
    if (coordinator.state.value.busy || pendingChange != null) return;
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
    String? label,
  }) async {
    if (coordinator.state.value.busy || pendingChange != null) return false;
    pendingChange = values.containsKey('rawId')
        ? 'raw:${values['rawId']}'
        : values.containsKey('selection')
        ? 'selection'
        : values.containsKey('trafficMode')
        ? 'method'
        : 'expert';
    _notify();
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
      final reconnect =
          coordinator.state.value.phase == ConnectionPhase.connected;
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
        // Failed applies rethrow, including after restoration. A successful plan
        // may legitimately commit Automatic instead of an unavailable selection.
        success = true;
        configuration = await coordinator.configuration;
      });
      return success;
    } finally {
      pendingChange = null;
      _notify();
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
    if (coordinator.state.value.busy ||
        pendingChange != null ||
        deletingRawIds.contains(row.id)) {
      return;
    }
    deletingRawIds.add(row.id);
    _notify();
    try {
      final expected = await coordinator.configuration;
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final active =
          expected.connection.expert && expected.connection.rawId == row.id;
      final connected =
          coordinator.state.value.phase == ConnectionPhase.connected;
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
        _notify();
      });
    } finally {
      deletingRawIds.remove(row.id);
      _notify();
    }
  }

  Future<void> resetTraffic(BuildContext context) async {
    final confirmed = await showConnectDialog<bool>(
      context,
      _resetTrafficDialog,
    );
    if (confirmed == true && context.mounted) await _clearTraffic(context);
  }

  Widget _resetTrafficDialog(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    var busy = false;
    return StatefulBuilder(
      builder: (context, setState) => ConnectDialog(
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
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ConnectDialogButton(
            label: l.prototypeResetTotals,
            destructive: true,
            icon: LucideIcons.rotateCcw,
            busy: busy,
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await _clearTraffic(context);
                    if (context.mounted &&
                        ModalRoute.of(context)?.isCurrent == true) {
                      Navigator.of(context).pop(false);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _clearTraffic(BuildContext context) async {
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
  }

  Future<void> addServers(BuildContext context) =>
      context.pushScoped(AppSecondaryDestination.serversImport);
  Future<void> editRaw(BuildContext context, [int? id]) =>
      context.pushScoped(AppSecondaryDestination.rawEditor, extra: id);
  void chooseServer(BuildContext context) =>
      context.goPrimaryRoot(AppPrimaryRoute.subscriptions);

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
                enabled: !coordinator.state.value.busy,
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
        close &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
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
    final view = coordinator.state.value;
    final connected = view.phase == ConnectionPhase.connected;
    final plan = connected ? view.plan : null;
    final settings = plan?.configuration.connection ?? configuration.connection;
    final planJson = plan?.toJson();
    final names = connected
        ? ((planJson?['entries'] as List?) ?? [])
              .map((entry) => (entry as Map)['name'] as String)
              .toList()
        : _previewEntries(settings).map((row) => serverName(row)).toList();
    final entryNames = names.join(' + ');
    final exit = connected
        ? ((planJson?['finalExit'] as Map?)?['name'] as String?)
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
  /// runtime plan. The actual connection still resolves through the coordinator.
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
            ServerSnapshot.fromRow(row);
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
    if (_closed || _trafficDialogOpen) return;
    _trafficDialogOpen = true;
    _syncTrafficVisibility();
    bool? reset;
    try {
      var confirmingReset = false;
      reset = await showConnectDialog<bool>(
        context,
        (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) {
            if (confirmingReset) return _resetTrafficDialog(dialogContext);
            final l = AppLocalizations.of(dialogContext)!;
            return ConnectDialog(
              title: l.prototypeTraffic,
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: ValueListenableBuilder<ConnectionView>(
                  valueListenable: coordinator.state,
                  builder: (_, view, _) =>
                      TrafficReadout(view: view, expandedGroups: true),
                ),
              ),
              actions: [
                ConnectDialogButton(
                  label: l.prototypeResetTotals,
                  secondary: true,
                  icon: LucideIcons.rotateCcw,
                  onPressed: () => setState(() => confirmingReset = true),
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
      if (!_closed) _syncTrafficVisibility();
    }
    if (reset == true && !_closed && context.mounted) {
      await _clearTraffic(context);
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
