import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/preparation.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/vpn/command_serial_executor.dart';

enum ConnectionPhase {
  disconnected,
  preparing,
  connecting,
  connected,
  disconnecting,
  recovering,
  failed,
}

class ConnectionView {
  final ConnectionPhase phase;
  final ConnectionPlan? plan;
  final RuntimeSnapshot? traffic;
  final bool metricsAvailable;
  final int uploadSpeed;
  final int downloadSpeed;
  final String? issue;
  final PlatformPermissionResult? permission;
  const ConnectionView({
    this.phase = ConnectionPhase.disconnected,
    this.plan,
    this.traffic,
    this.metricsAvailable = false,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
    this.issue,
    this.permission,
  });
  bool get busy =>
      phase != ConnectionPhase.connected &&
      phase != ConnectionPhase.disconnected &&
      phase != ConnectionPhase.failed;
  bool get failed =>
      phase == ConnectionPhase.failed ||
      (issue != null &&
          !const {
            'cancelled',
            'selectionReset',
            'previousSettingsRestored',
          }.contains(issue));
}

typedef PrepareConnection = Future<ConnectionPlan> Function(
  ConnectionConfiguration,
  Future<void>,
);

/// All user/system-entry commands share one serial queue. No SQLite transaction
/// remains open while awaiting a permission prompt, a probe or a native VPN.
class ConnectionCoordinator with WidgetsBindingObserver {
  static final instance = ConnectionCoordinator();
  final AppDatabase db;
  late final PrepareConnection _prepare;
  late final Future<HostConnection> Function(ConnectionPlan) _start;
  late final Future<HostConnection> Function(ConnectionPlan?) _stop;
  late final Future<HostConnection> Function(Iterable<ConnectionPlan>) _inspect;
  late final Future<HostConnection> Function(
    Iterable<ConnectionPlan>,
    VpnStatus,
  )
  _inspectObserved;
  late final Future<RuntimeSnapshot> Function(ConnectionPlan) _readTraffic;
  late final Future<ConnectionPlan?> Function(String?) _readPlan;
  final Stream<VpnStatus> _statusEvents;
  final bool Function() _needsStatusPolling;
  late final Future<RuntimeSnapshot?> Function(ConnectionPlan?) _resetTraffic;
  late final Future<RestoreReplay?> Function(ConnectionPlan?) _revokeReplay;
  final _commands = CommandSerialExecutor();
  final state = ValueNotifier(const ConnectionView());
  Future<void>? _initializing;
  Future<void>? _connectRequested;
  StreamSubscription<VpnStatus>? _statusSubscription;
  Timer? _statusPoll;
  Timer? _trafficPoll;
  bool _polling = false;
  bool _readingTraffic = false;
  bool _trafficVisible = false;
  bool _ready = false;
  VpnStatus? _lastNativeStatus;
  VpnStatus? _pendingStatus;
  int _commandGeneration = 0;
  int _trafficGeneration = 0;
  bool _commandActive = false;
  Completer<void>? _cancel;
  ConnectionPlan? _pendingPlan;
  Set<int> _preparingNodeIds = {};
  bool _closed = false;
  bool _observingLifecycle = false;
  bool _foreground = true;
  bool _resetSpeed = true;

  ConnectionCoordinator({
    AppDatabase? database,
    PrepareConnection? prepare,
    Future<HostConnection> Function(ConnectionPlan)? start,
    Future<HostConnection> Function(ConnectionPlan?)? stop,
    Future<HostConnection> Function(Iterable<ConnectionPlan>)? inspect,
    Future<HostConnection> Function(Iterable<ConnectionPlan>, VpnStatus)?
    inspectObserved,
    Future<RuntimeSnapshot> Function(ConnectionPlan)? readTraffic,
    Future<ConnectionPlan?> Function(String?)? readPlan,
    Stream<VpnStatus>? statusEvents,
    bool Function()? needsStatusPolling,
    Future<RuntimeSnapshot?> Function(ConnectionPlan?)? resetTraffic,
    Future<RestoreReplay?> Function(ConnectionPlan?)? revokeReplay,
  }) : db = database ?? AppDatabase(),
       _statusEvents =
           statusEvents ?? AppFlutterApi().vpnStatusController.stream,
       _needsStatusPolling =
           needsStatusPolling ?? (() => AppHostApi().needsVpnStatusPolling) {
    final host = ConnectionRuntimeHost();
    _start = start ?? host.start;
    _stop = stop ?? host.stop;
    _inspect = inspect ?? host.inspect;
    _inspectObserved =
        inspectObserved ??
        ((plans, status) => host.inspect(plans, observedStatus: status));
    _readTraffic = readTraffic ?? host.query;
    _readPlan = readPlan ?? host.readPlan;
    _resetTraffic = resetTraffic ?? host.resetTraffic;
    _revokeReplay = revokeReplay ?? host.revokeReplay;
    _prepare =
        prepare ??
        ((configuration, cancelled) => ConnectionPreparation(db: db).prepare(
          configuration,
          cancelled: cancelled,
          onResolved: reportResolvedNodes,
        ));
  }

  Future<ConnectionConfiguration> get configuration async =>
      ConnectionConfiguration.fromJson(
        jsonDecode((await db.connectionStateDao.read()).settingsJson)
            as Map<String, dynamic>,
      );

  /// The database stores a reference, not another copy of the private plan.
  Future<ConnectionPlan?> readConfirmedPlan() async =>
      _readPlan((await db.connectionStateDao.read()).confirmedPlanId);

  /// Custom preparation (node/route drafts) shares the same temporary reference
  /// protection as the default path. apply clears it on success and failure.
  void reportResolvedNodes(Set<int> ids) {
    _preparingNodeIds.addAll(ids);
  }

  Future<void> initialize({bool poll = true, bool registerReferences = true}) {
    return _initializing ??= _commands
        .run((_) async {
          if (registerReferences) {
            SubscriptionService().referenceReader = readReferences;
          }
          if (poll) {
            _statusSubscription ??= _statusEvents.listen(_onNativeStatus);
          }
          final row = await db.connectionStateDao.read();
          _publish(await _inspect(await _known(row)));
          _ready = true;
          if (poll) {
            WidgetsBinding.instance.addObserver(this);
            _observingLifecycle = true;
            _foreground =
                WidgetsBinding.instance.lifecycleState == null ||
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed;
            _syncPolling();
            _drainNativeStatus();
          }
        })
        .catchError((Object error, StackTrace stack) {
          unawaited(_statusSubscription?.cancel());
          _statusSubscription = null;
          _initializing = null;
          _lastNativeStatus = null;
          state.value = ConnectionView(
            phase: ConnectionPhase.failed,
            issue: error is ConnectionHostException
                ? error.reason
                : 'runtimeUnavailable',
            permission: error is ConnectionHostException
                ? error.permission
                : null,
          );
          Error.throwWithStackTrace(error, stack);
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    _resetSpeed = true;
    _trafficGeneration++;
    _syncPolling();
    if (_foreground && !wasForeground && _ready && _observingLifecycle) {
      unawaited(refresh());
    }
  }

  /// Page visibility is demand, not ownership of the VPN or its saved counters.
  /// In particular, a retained but offstage navigation branch has no demand.
  void setTrafficVisible(bool visible) {
    if (_closed || _trafficVisible == visible) return;
    _trafficVisible = visible;
    _trafficGeneration++;
    _resetSpeed = true;
    _syncPolling();
  }

  bool get _trafficWanted =>
      _ready &&
      !_closed &&
      _foreground &&
      _trafficVisible &&
      !_commandActive &&
      _lastNativeStatus == VpnStatus.connected &&
      state.value.phase == ConnectionPhase.connected &&
      state.value.plan != null;

  void _syncPolling() {
    final watchStatus =
        _ready &&
        !_closed &&
        _foreground &&
        _observingLifecycle &&
        _needsStatusPolling();
    if (!watchStatus) {
      _statusPoll?.cancel();
      _statusPoll = null;
    } else {
      // ponytail: only query-only hosts need this fallback; replace it when
      // their existing bridge can report external state changes directly.
      _statusPoll ??= Timer.periodic(const Duration(seconds: 5), (_) {
        if (_needsStatusPolling()) {
          unawaited(refresh());
        } else {
          _syncPolling();
        }
      });
    }
    if (!_trafficWanted) {
      if (_trafficPoll != null) {
        _trafficPoll!.cancel();
        _trafficPoll = null;
        _trafficGeneration++;
        _resetSpeed = true;
      }
    } else if (_trafficPoll == null) {
      _trafficPoll = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(refreshTraffic());
      });
      unawaited(refreshTraffic());
    }
  }

  void _onNativeStatus(VpnStatus status) {
    if (_closed || status == _lastNativeStatus) return;
    _lastNativeStatus = status;
    _pendingStatus = status;
    _trafficGeneration++;
    _resetSpeed = true;
    _syncPolling();
    _drainNativeStatus();
  }

  void _drainNativeStatus() {
    if (!_ready || _closed || _commandActive || _polling) return;
    final status = _pendingStatus;
    if (status == null) return;
    _pendingStatus = null;
    unawaited(refresh(observedStatus: status));
  }

  Future<SubscriptionNodeReferences> readReferences() async {
    final stored = await configuration;
    if (state.value.plan == null &&
        _pendingPlan == null &&
        _preparingNodeIds.isEmpty &&
        state.value.phase != ConnectionPhase.disconnected &&
        _lastNativeStatus != VpnStatus.disconnected) {
      // An unknown live plan cannot safely yield an empty protection set.
      throw const ConnectionHostException('runtimeSnapshotUnavailable');
    }
    return SubscriptionNodeReferences(
      runningIds: {
        ...?state.value.plan?.nodeIds,
        ...?_pendingPlan?.nodeIds,
        ..._preparingNodeIds,
      },
      fixedId: stored.connection.selection.kind == SelectionKind.server
          ? stored.connection.selection.id
          : null,
      finalExitId: stored.connection.smart.finalExitId,
    );
  }

  Future<List<ConnectionPlan>> _known(ConnectionStateData row) async => [
    ?state.value.plan,
    ?_pendingPlan,
    ?await _readPlan(row.confirmedPlanId),
  ];

  Future<void> refresh({VpnStatus? observedStatus}) async {
    if (_closed || (!_foreground && observedStatus == null)) return;
    if (_commandActive || _polling) {
      if (observedStatus != null) _pendingStatus = observedStatus;
      return;
    }
    _polling = true;
    final commandGeneration = _commandGeneration;
    try {
      await DataMaintenance.run(() async {
        final row = await db.connectionStateDao.read();
        final plans = await _known(row);
        final current = observedStatus == null
            ? await _inspect(plans)
            : await _inspectObserved(plans, observedStatus);
        if (!_commandActive &&
            !_closed &&
            commandGeneration == _commandGeneration &&
            (_pendingStatus == null || _pendingStatus == current.status)) {
          _publish(current, keepResult: true);
        }
      });
    } catch (_) {
      if (!_commandActive &&
          !_closed &&
          commandGeneration == _commandGeneration &&
          (_pendingStatus == null || _pendingStatus == observedStatus)) {
        final old = state.value;
        if (observedStatus != null) {
          // A confirmed native state remains true even if its saved plan or
          // counters cannot be read. Do not lose an external disconnect.
          _publish(
            HostConnection(
              observedStatus,
              plan: old.plan,
              traffic: old.traffic,
            ),
            issue: old.issue ?? 'runtimeUnavailable',
            permission: old.permission,
          );
        } else {
          state.value = ConnectionView(
            phase: old.phase,
            plan: old.plan,
            traffic: old.traffic,
            issue: old.issue ?? 'runtimeUnavailable',
            permission: old.permission,
          );
        }
      }
    } finally {
      _polling = false;
      _syncPolling();
      _drainNativeStatus();
    }
  }

  /// Live sampling never queries native VPN status. A failed HTTP request is
  /// only an unavailable sample, not a disconnection or a reason to reconnect.
  Future<void> refreshTraffic() async {
    if (!_trafficWanted || _readingTraffic || _pendingStatus != null) return;
    final plan = state.value.plan!;
    final generation = _trafficGeneration;
    _readingTraffic = true;
    bool stillCurrent() =>
        _trafficWanted &&
        generation == _trafficGeneration &&
        state.value.plan?.id == plan.id;
    try {
      await DataMaintenance.run(() async {
        final traffic = await _readTraffic(plan);
        if (stillCurrent()) {
          _publish(
            HostConnection(VpnStatus.connected, plan: plan, traffic: traffic),
            keepResult: true,
            liveTraffic: true,
          );
        }
      });
    } catch (_) {
      if (stillCurrent()) {
        final old = state.value;
        _resetSpeed = true;
        state.value = ConnectionView(
          phase: old.phase,
          plan: old.plan,
          traffic: old.traffic,
          issue: old.issue,
          permission: old.permission,
        );
      }
    } finally {
      _readingTraffic = false;
    }
  }

  Future<void> connect() => _connectRequested ??= _connectOnce().whenComplete(
    () => _connectRequested = null,
  );

  Future<void> _connectOnce() async {
    await initialize();
    if (state.value.phase == ConnectionPhase.connected || state.value.busy) {
      return;
    }
    await apply(await configuration, connect: true);
  }

  /// UI has already confirmed a disruptive change before calling this method.
  /// Metadata/unselected-asset edits use affectsRuntime:false and still commit
  /// asset plus connection values in one transaction.
  Future<void> apply(
    ConnectionConfiguration next, {
    bool connect = false,
    bool disconnect = false,
    bool affectsRuntime = true,
    bool allowReconnect = true,
    String? expectedConfiguration,
    Future<void> Function()? writeAssets,
    PrepareConnection? prepare,
  }) => _run(() async {
    if (connect && disconnect) {
      throw ArgumentError('Conflicting connection action');
    }
    final row = await db.connectionStateDao.read();
    if (expectedConfiguration != null &&
        (await configuration).encode() != expectedConfiguration) {
      throw const ConnectionHostException('configurationChanged');
    }
    final current = await _inspect(await _known(row));
    final shouldStart =
        !disconnect && (connect || (affectsRuntime && current.connected));
    final shouldStop = disconnect && current.status != VpnStatus.disconnected;
    // Recheck after preceding commands finish: a disconnected editor may have
    // queued behind Connect without ever asking the user to reconnect.
    if ((shouldStart || shouldStop) && current.connected && !allowReconnect) {
      throw const ConnectionHostException('reconnectRequired');
    }
    if (!shouldStart && !shouldStop) {
      RestoreReplay? restoreReplay;
      if ((affectsRuntime || disconnect) &&
          current.status == VpnStatus.disconnected &&
          row.confirmedPlanId != null &&
          (writeAssets != null ||
              next.encode() != (await configuration).encode())) {
        restoreReplay = await _revokeReplay(
          await _readPlan(row.confirmedPlanId),
        );
      }
      try {
        await db.connectionStateDao.commit(
          baseRevision: row.revision,
          settingsJson: next.encode(),
          confirmedPlanId: row.confirmedPlanId,
          writeAssets: writeAssets,
        );
      } catch (_) {
        await restoreReplay?.call();
        rethrow;
      }
      _publish(current);
      return;
    }
    final cancellation = Completer<void>();
    _cancel = cancellation;
    final old = current.connected ? current.plan : null;
    if (current.connected && old == null) {
      throw const ConnectionHostException('runtimeSnapshotUnavailable');
    }
    state.value = ConnectionView(
      phase: ConnectionPhase.preparing,
      plan: old,
      traffic: current.traffic,
    );
    bool touchedHost = false;
    RestoreReplay? restoreReplay;
    try {
      // Keep the old nodes while this call may still restore the old plan.
      _preparingNodeIds = {...?old?.nodeIds};
      final plan = disconnect
          ? null
          : await (prepare ?? _prepare)(next, cancellation.future);
      _checkCancelled(cancellation);
      _pendingPlan = plan;
      var running = current;
      if (current.status != VpnStatus.disconnected) {
        touchedHost = true;
        state.value = ConnectionView(
          phase: ConnectionPhase.disconnecting,
          plan: old,
          traffic: current.traffic,
        );
        running = await _stop(old);
        if (running.status != VpnStatus.disconnected) {
          throw const ConnectionHostException('stopNotConfirmed');
        }
      }
      _checkCancelled(cancellation);
      if (plan != null) {
        touchedHost = true;
        state.value = ConnectionView(
          phase: ConnectionPhase.connecting,
          traffic: current.traffic,
        );
        running = await _start(plan);
        _checkCancelled(cancellation);
        if (!running.connected || running.plan?.id != plan.id) {
          throw const ConnectionHostException('startNotConfirmed');
        }
      }
      if (disconnect) {
        restoreReplay = await _revokeReplay(old);
      }
      await db.connectionStateDao.commit(
        baseRevision: row.revision,
        settingsJson: (plan?.configuration ?? next).encode(),
        confirmedPlanId: plan?.id ?? row.confirmedPlanId,
        writeAssets: () async {
          await writeAssets?.call();
          _checkCancelled(cancellation);
        },
      );
      _publish(running, issue: plan?.notice);
    } catch (error) {
      var permission = error is ConnectionHostException
          ? error.permission
          : null;
      try {
        await restoreReplay?.call();
        var recovered = current;
        var restoreFailed = false;
        if (touchedHost) {
          // Even a start timeout may leave a live tunnel; stop it before restoring.
          recovered = await _stop(_pendingPlan);
          if (old != null) {
            state.value = ConnectionView(
              phase: ConnectionPhase.recovering,
              traffic: recovered.traffic,
            );
            try {
              recovered = await _start(old);
              if (!recovered.connected || recovered.plan?.id != old.id) {
                throw const ConnectionHostException('restoreFailed');
              }
            } catch (restoreError) {
              if (restoreError is ConnectionHostException) {
                permission ??= restoreError.permission;
              }
              recovered = await _stop(old);
              restoreFailed = true;
            }
          } else if (recovered.status == VpnStatus.disconnected) {
            await _revokeReplay(_pendingPlan);
          }
        }
        _publish(
          recovered,
          issue: restoreFailed
              ? 'restoreFailed'
              : cancellation.isCompleted
              ? 'cancelled'
              : error is ConnectionHostException
              ? error.reason
              : 'changeFailed',
          permission: permission,
        );
      } catch (recoveryError) {
        await _publishHostFailure(
          'restoreFailed',
          error: recoveryError,
          permission: permission,
        );
        rethrow;
      }
      rethrow;
    } finally {
      _pendingPlan = null;
      _preparingNodeIds = {};
      _cancel = null;
    }
  });

  void cancel() {
    if (_cancel?.isCompleted == false) _cancel!.complete();
  }

  void _checkCancelled(Completer<void> cancellation) {
    if (cancellation.isCompleted) {
      throw const ConnectionHostException('cancelled');
    }
  }

  Future<void> disconnect() {
    cancel();
    return _run(stopForMaintenance);
  }

  /// Restore/clear already hold DataMaintenance.exclusive. Do not re-enter it.
  Future<void> stopForMaintenance() async {
    try {
      final row = await db.connectionStateDao.read();
      final current = await _inspect(await _known(row));
      state.value = ConnectionView(
        phase: ConnectionPhase.disconnecting,
        plan: current.plan,
        traffic: current.traffic,
      );
      _publish(await _stop(current.plan));
    } catch (error) {
      await _publishHostFailure('stopFailed', error: error);
      rethrow;
    }
  }

  Future<void> _publishHostFailure(
    String issue, {
    required Object error,
    PlatformPermissionResult? permission,
  }) async {
    ConnectionPlan? plan;
    var traffic = state.value.traffic;
    _lastNativeStatus = null;
    try {
      final row = await db.connectionStateDao.read();
      final current = await _inspect(await _known(row));
      _lastNativeStatus = current.status;
      traffic = current.traffic ?? traffic;
      // The actual running plan can differ from saved settings after a failed
      // change. Keep it visible and protect its nodes without committing it.
      if (current.status != VpnStatus.disconnected) {
        plan = current.plan;
      }
    } catch (_) {
      // Unknown host state stays an explicit failure; retry inspects it again.
    }
    state.value = ConnectionView(
      phase: ConnectionPhase.failed,
      plan: plan,
      traffic: traffic,
      issue: issue,
      permission:
          permission ??
          (error is ConnectionHostException ? error.permission : null),
    );
  }

  Future<void> resetTraffic() => _run(() async {
    final row = await db.connectionStateDao.read();
    final current = await _inspect(await _known(row));
    final snapshot = await _resetTraffic(current.plan);
    final previous = current.traffic ?? state.value.traffic;
    _publish(
      HostConnection(
        current.status,
        plan: current.plan,
        traffic:
            snapshot ??
            previous?.withTotals(
              uplink: 0,
              downlink: 0,
              resetGeneration: previous.resetGeneration + 1,
            ),
      ),
    );
  });

  Future<void> _run(Future<void> Function() action) =>
      DataMaintenance.run(() async {
        await initialize();
        return _commands.run((_) async {
          _commandActive = true;
          _commandGeneration++;
          _trafficGeneration++;
          _resetSpeed = true;
          _syncPolling();
          try {
            await action();
          } finally {
            _commandActive = false;
            _syncPolling();
            _drainNativeStatus();
          }
        });
      });

  void _publish(
    HostConnection current, {
    String? issue,
    PlatformPermissionResult? permission,
    bool keepResult = false,
    bool liveTraffic = false,
  }) {
    final old = state.value;
    // Query replies also travel through the event stream. Consume only the
    // matching reply; a newer, different native status must still be reconciled.
    if (_pendingStatus == current.status) _pendingStatus = null;
    _lastNativeStatus = current.status;
    if (keepResult) {
      // Reconciliation/sampling does not replace the last command's result.
      // A newly successful system connection resolves an old disconnected error.
      if (!(current.connected && old.phase != ConnectionPhase.connected)) {
        if (old.issue != 'runtimeUnavailable') issue ??= old.issue;
        permission ??= old.permission;
      }
    }
    final previous = state.value.traffic;
    final next = current.traffic;
    final sameSession =
        current.connected &&
        old.phase == ConnectionPhase.connected &&
        current.plan?.id == old.plan?.id &&
        next != null &&
        previous?.sessionId == next.sessionId;
    // A saved 30s snapshot must not replace newer live counters during a status
    // refresh. Explicit resets still publish their new totals/reset generation.
    final retainLive =
        !liveTraffic &&
        keepResult &&
        _trafficWanted &&
        old.metricsAvailable &&
        sameSession &&
        previous!.sampledAtMs >= next.sampledAtMs;
    final display = retainLive ? previous : next ?? previous;
    int upload = 0, download = 0;
    if (liveTraffic &&
        !_resetSpeed &&
        current.connected &&
        next?.available == true &&
        previous?.sessionId == next?.sessionId) {
      final elapsed = next!.sampledAtMs - previous!.sampledAtMs;
      if (elapsed > 0 &&
          next.uplink >= previous.uplink &&
          next.downlink >= previous.downlink) {
        upload = ((next.uplink - previous.uplink) * 1000 / elapsed).round();
        download = ((next.downlink - previous.downlink) * 1000 / elapsed)
            .round();
      }
    }
    if (liveTraffic) _resetSpeed = false;
    state.value = ConnectionView(
      phase: switch (current.status) {
        VpnStatus.connected => ConnectionPhase.connected,
        VpnStatus.connecting => ConnectionPhase.connecting,
        VpnStatus.disconnecting => ConnectionPhase.disconnecting,
        VpnStatus.disconnected => ConnectionPhase.disconnected,
      },
      plan: current.status == VpnStatus.disconnected ? null : current.plan,
      traffic: display,
      metricsAvailable:
          current.connected &&
          (retainLive || (liveTraffic && next?.available == true)),
      uploadSpeed: retainLive ? old.uploadSpeed : upload,
      downloadSpeed: retainLive ? old.downloadSpeed : download,
      issue:
          issue ??
          (current.connected && current.plan == null
              ? 'runtimeSnapshotUnavailable'
              : null),
      permission: permission,
    );
    _syncPolling();
  }

  void clearTrafficView() {
    _commandGeneration++;
    _trafficGeneration++;
    _pendingStatus = null;
    _lastNativeStatus = null;
    _resetSpeed = true;
    state.value = const ConnectionView();
    _syncPolling();
  }

  void dispose() {
    _closed = true;
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    cancel();
    unawaited(_statusSubscription?.cancel());
    _statusPoll?.cancel();
    _trafficPoll?.cancel();
    state.dispose();
  }
}
