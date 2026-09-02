import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:onexray/core/db/database/database.dart';
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
  late final Future<RuntimeSnapshot?> Function(ConnectionPlan?) _resetTraffic;
  final _commands = CommandSerialExecutor();
  final state = ValueNotifier(const ConnectionView());
  Future<void>? _initializing;
  Future<void>? _connectRequested;
  Timer? _poll;
  bool _polling = false;
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
    Future<RuntimeSnapshot?> Function(ConnectionPlan?)? resetTraffic,
  }) : db = database ?? AppDatabase() {
    final host = ConnectionRuntimeHost();
    _start = start ?? host.start;
    _stop = stop ?? host.stop;
    _inspect = inspect ?? host.inspect;
    _resetTraffic = resetTraffic ?? host.resetTraffic;
    _prepare =
        prepare ??
        ((configuration, cancelled) => ConnectionPreparation(db: db).prepare(
          configuration,
          cancelled: cancelled,
          onResolved: (ids) => _preparingNodeIds = ids,
        ));
  }

  Future<ConnectionConfiguration> get configuration async =>
      ConnectionConfiguration.fromJson(
        jsonDecode((await db.connectionStateDao.read()).settingsJson)
            as Map<String, dynamic>,
      );

  Future<void> initialize({bool poll = true, bool registerReferences = true}) {
    return _initializing ??= _commands
        .run((_) async {
          if (registerReferences) {
            SubscriptionService().referenceReader = readReferences;
          }
          await _recover();
          if (poll) {
            WidgetsBinding.instance.addObserver(this);
            _observingLifecycle = true;
            didChangeAppLifecycleState(
              WidgetsBinding.instance.lifecycleState ??
                  AppLifecycleState.resumed,
            );
          }
        })
        .catchError((Object error, StackTrace stack) {
          _initializing = null;
          Error.throwWithStackTrace(error, stack);
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _poll?.cancel();
    _poll = null;
    _resetSpeed = true;
    if (_foreground && !_closed && _observingLifecycle) {
      _poll = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(refresh()),
      );
      unawaited(refresh());
    }
  }

  Future<SubscriptionNodeReferences> readReferences() async {
    final stored = await configuration;
    final row = await db.connectionStateDao.read();
    return SubscriptionNodeReferences(
      runningIds: {
        ...?state.value.plan?.nodeIds,
        ...?_pendingPlan?.nodeIds,
        ..._preparingNodeIds,
        if (row.pendingApplyJson != null)
          for (final plan in _known(row)) ...plan.nodeIds,
      },
      fixedId: stored.connection.selection.kind == SelectionKind.server
          ? stored.connection.selection.id
          : null,
      finalExitId: stored.connection.smart.finalExitId,
    );
  }

  Iterable<ConnectionPlan> _known(ConnectionStateData row) sync* {
    if (state.value.plan != null) yield state.value.plan!;
    if (row.confirmedSnapshotJson != null) {
      yield ConnectionPlan.decode(row.confirmedSnapshotJson!);
    }
    if (row.pendingApplyJson != null) {
      final pending = jsonDecode(row.pendingApplyJson!) as Map<String, dynamic>;
      for (final key in ['old', 'next']) {
        if (pending[key] is String) {
          yield ConnectionPlan.decode(pending[key] as String);
        }
      }
    }
  }

  Future<void> _recover() async {
    PlatformPermissionResult? permission;
    try {
      final row = await db.connectionStateDao.read();
      final current = await _inspect(_known(row));
      final pending = row.pendingApplyJson;
      if (pending == null) {
        _publish(current);
        return;
      }
      state.value = ConnectionView(
        phase: ConnectionPhase.recovering,
        traffic: current.traffic,
      );
      final record = jsonDecode(pending) as Map<String, dynamic>;
      final old = record['old'] == null
          ? null
          : ConnectionPlan.decode(record['old'] as String);
      // Pending means the data transaction did not commit. Never promote the
      // draft just because its native session happened to start before a crash.
      HostConnection recovered = current;
      if (current.status != VpnStatus.disconnected &&
          current.plan?.id != old?.id) {
        recovered = await _stop(current.plan);
      }
      if (old != null &&
          (!recovered.connected || recovered.plan?.id != old.id)) {
        try {
          recovered = await _start(old);
          if (!recovered.connected || recovered.plan?.id != old.id) {
            throw const ConnectionHostException('restoreFailed');
          }
        } catch (error) {
          if (error is ConnectionHostException) permission = error.permission;
          recovered = await _stop(old);
          await db.connectionStateDao.clearPending(pending);
          _publish(recovered, issue: 'restoreFailed', permission: permission);
          return;
        }
      }
      await db.connectionStateDao.clearPending(pending);
      _publish(recovered, issue: 'previousSettingsRestored');
    } catch (error) {
      await _publishHostFailure(
        'restoreFailed',
        error: error,
        permission: permission,
      );
      rethrow;
    }
  }

  Future<void> refresh() async {
    if (_closed || !_foreground || _commandActive || _polling) return;
    _polling = true;
    try {
      await DataMaintenance.run(() async {
        final row = await db.connectionStateDao.read();
        if (row.pendingApplyJson != null) return;
        final current = await _inspect(_known(row));
        if (!_commandActive && !_closed) _publish(current, keepResult: true);
      });
    } catch (_) {
      if (!_commandActive && !_closed) {
        final old = state.value;
        state.value = ConnectionView(
          phase: old.phase,
          plan: old.plan,
          traffic: old.traffic,
          issue: old.issue ?? 'runtimeUnavailable',
          permission: old.permission,
        );
      }
    } finally {
      _polling = false;
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
    bool affectsRuntime = true,
    Future<void> Function()? writeAssets,
    PrepareConnection? prepare,
  }) => _run(() async {
    final row = await db.connectionStateDao.read();
    final current = await _inspect(_known(row));
    final shouldStart = connect || (affectsRuntime && current.connected);
    if (!shouldStart) {
      await db.connectionStateDao.commit(
        baseRevision: row.revision,
        settingsJson: next.encode(),
        confirmedSnapshotJson: row.confirmedSnapshotJson,
        writeAssets: writeAssets,
      );
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
    String? pending;
    bool touchedHost = false;
    try {
      final plan = await (prepare ?? _prepare)(next, cancellation.future);
      _checkCancelled(cancellation);
      _pendingPlan = plan;
      pending = jsonEncode({
        'attemptId': plan.id,
        'old': old?.encode(),
        'next': plan.encode(),
      });
      await db.connectionStateDao.beginApply(row.revision, pending);
      _checkCancelled(cancellation);
      if (current.status != VpnStatus.disconnected) {
        touchedHost = true;
        state.value = ConnectionView(
          phase: ConnectionPhase.disconnecting,
          plan: old,
          traffic: current.traffic,
        );
        await _stop(old);
      }
      _checkCancelled(cancellation);
      touchedHost = true;
      state.value = ConnectionView(
        phase: ConnectionPhase.connecting,
        traffic: current.traffic,
      );
      final running = await _start(plan);
      _checkCancelled(cancellation);
      if (!running.connected || running.plan?.id != plan.id) {
        throw const ConnectionHostException('startNotConfirmed');
      }
      await db.connectionStateDao.commit(
        baseRevision: row.revision,
        settingsJson: plan.configuration.encode(),
        confirmedSnapshotJson: plan.encode(),
        writeAssets: () async {
          await writeAssets?.call();
          _checkCancelled(cancellation);
        },
      );
      pending = null;
      _publish(running, issue: plan.notice);
    } catch (error) {
      var permission = error is ConnectionHostException
          ? error.permission
          : null;
      try {
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
          }
        }
        if (pending != null) await db.connectionStateDao.clearPending(pending);
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
      final current = await _inspect(_known(row));
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
    try {
      final row = await db.connectionStateDao.read();
      final current = await _inspect(_known(row));
      traffic = current.traffic ?? traffic;
      final pending = row.pendingApplyJson;
      final oldJson = pending == null
          ? null
          : (jsonDecode(pending) as Map<String, dynamic>)['old'] as String?;
      final oldId = oldJson == null ? null : ConnectionPlan.decode(oldJson).id;
      // A readable native draft is still uncommitted. Never show it as the
      // saved selection, nor show a remembered old snapshot as actually running.
      if (current.status != VpnStatus.disconnected &&
          (pending == null || current.plan?.id == oldId)) {
        plan = current.plan;
      }
    } catch (_) {
      // Unknown host state stays an explicit failure; retry keeps the journal.
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
    final current = await _inspect(_known(row));
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
          try {
            if ((await db.connectionStateDao.read()).pendingApplyJson != null) {
              await _recover();
            }
            await action();
          } finally {
            _commandActive = false;
          }
        });
      });

  void _publish(
    HostConnection current, {
    String? issue,
    PlatformPermissionResult? permission,
    bool keepResult = false,
  }) {
    final old = state.value;
    if (keepResult) {
      // Polling updates native state/metrics, not the last command's result.
      // A newly successful system connection resolves an old disconnected error.
      if (!(current.connected && old.phase != ConnectionPhase.connected)) {
        if (old.issue != 'runtimeUnavailable') issue ??= old.issue;
        permission ??= old.permission;
      }
    }
    final previous = state.value.traffic;
    final next = current.traffic;
    int upload = 0, download = 0;
    if (!_resetSpeed &&
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
    _resetSpeed = false;
    state.value = ConnectionView(
      phase: switch (current.status) {
        VpnStatus.connected => ConnectionPhase.connected,
        VpnStatus.connecting => ConnectionPhase.connecting,
        VpnStatus.disconnecting => ConnectionPhase.disconnecting,
        VpnStatus.disconnected => ConnectionPhase.disconnected,
      },
      plan: current.status == VpnStatus.disconnected ? null : current.plan,
      traffic: next ?? previous,
      metricsAvailable: current.connected && next?.available == true,
      uploadSpeed: upload,
      downloadSpeed: download,
      issue:
          issue ??
          (current.connected && current.plan == null
              ? 'runtimeSnapshotUnavailable'
              : null),
      permission: permission,
    );
  }

  void clearTrafficView() {
    _resetSpeed = true;
    state.value = const ConnectionView();
  }

  void dispose() {
    _closed = true;
    if (_observingLifecycle) WidgetsBinding.instance.removeObserver(this);
    cancel();
    _poll?.cancel();
    state.dispose();
  }
}
