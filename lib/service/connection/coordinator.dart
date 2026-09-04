import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/connection/preparation.dart';
import 'package:onexray/service/connection/runtime.dart';
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
  failed,
}

class ConnectionView {
  final ConnectionPhase phase;
  final ConnectionRuntime? runtime;
  final RuntimeSnapshot? traffic;
  final bool metricsAvailable;
  final int uploadSpeed;
  final int downloadSpeed;
  final String? issue;
  final PlatformPermissionResult? permission;
  const ConnectionView({
    this.phase = ConnectionPhase.disconnected,
    this.runtime,
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
      (issue != null && !const {'cancelled', 'selectionReset'}.contains(issue));
}

typedef PrepareConnection = Future<ConnectionRuntime> Function(
  ConnectionConfiguration,
  Future<void>,
);

/// All user/system-entry commands share one serial queue. No SQLite transaction
/// remains open while awaiting a permission prompt, a probe or a native VPN.
class ConnectionCoordinator with WidgetsBindingObserver {
  static final instance = ConnectionCoordinator();
  final AppDatabase db;
  late final PrepareConnection _prepare;
  late final Future<HostConnection> Function(ConnectionRuntime) _start;
  late final Future<HostConnection> Function() _stop;
  late final Future<HostConnection> Function(Iterable<ConnectionRuntime>)
  _inspect;
  late final Future<HostConnection> Function(
    Iterable<ConnectionRuntime>,
    VpnStatus,
  )
  _inspectObserved;
  late final Future<RuntimeSnapshot> Function(ConnectionRuntime) _readTraffic;
  late final Future<ConnectionRuntime?> Function() _readRuntime;
  final Stream<VpnStatus> _statusEvents;
  final bool Function() _needsStatusPolling;
  late final Future<RuntimeSnapshot?> Function(ConnectionRuntime?)
  _resetTraffic;
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
  ConnectionRuntime? _pendingRuntime;
  Set<int> _preparingNodeIds = {};
  bool _closed = false;
  bool _observingLifecycle = false;
  bool _foreground = true;
  bool _resetSpeed = true;
  bool _failureLatched = false;

  ConnectionCoordinator({
    AppDatabase? database,
    PrepareConnection? prepare,
    Future<HostConnection> Function(ConnectionRuntime)? start,
    Future<HostConnection> Function()? stop,
    Future<HostConnection> Function(Iterable<ConnectionRuntime>)? inspect,
    Future<HostConnection> Function(Iterable<ConnectionRuntime>, VpnStatus)?
    inspectObserved,
    Future<RuntimeSnapshot> Function(ConnectionRuntime)? readTraffic,
    Future<ConnectionRuntime?> Function()? readRuntime,
    Stream<VpnStatus>? statusEvents,
    bool Function()? needsStatusPolling,
    Future<RuntimeSnapshot?> Function(ConnectionRuntime?)? resetTraffic,
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
        ((runtimes, status) => host.inspect(runtimes, observedStatus: status));
    _readTraffic = readTraffic ?? host.query;
    _readRuntime = readRuntime ?? host.readRuntime;
    _resetTraffic = resetTraffic ?? host.resetTraffic;
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

  Future<ConnectionRuntime?> readCurrentRuntime() => _readRuntime();

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
          _publish(await _inspect(await _known()));
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
          _failureLatched = true;
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
      state.value.runtime != null;

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
    if (state.value.runtime == null &&
        _pendingRuntime == null &&
        _preparingNodeIds.isEmpty &&
        state.value.phase != ConnectionPhase.disconnected &&
        _lastNativeStatus != VpnStatus.disconnected) {
      throw const ConnectionHostException('runtimeMetadataUnavailable');
    }
    return SubscriptionNodeReferences(
      runningIds: {
        ...?state.value.runtime?.nodeIds,
        ...?_pendingRuntime?.nodeIds,
        ..._preparingNodeIds,
      },
      fixedId: stored.connection.selection.kind == SelectionKind.server
          ? stored.connection.selection.id
          : null,
      finalExitId: stored.connection.smart.finalExitId,
    );
  }

  Future<List<ConnectionRuntime>> _known() async {
    final values = <ConnectionRuntime>[
      ?state.value.runtime,
      ?_pendingRuntime,
      ?await _readRuntime(),
    ];
    final identities = <String>{};
    return values.where((value) => identities.add(value.identity)).toList();
  }

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
        final runtimes = await _known();
        final current = observedStatus == null
            ? await _inspect(runtimes)
            : await _inspectObserved(runtimes, observedStatus);
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
          // A confirmed native state remains true even if its runtime metadata
          // or counters cannot be read. Do not lose an external disconnect.
          _publish(
            HostConnection(
              observedStatus,
              runtime: old.runtime,
              traffic: old.traffic,
            ),
            issue: old.issue ?? 'runtimeUnavailable',
            permission: old.permission,
          );
        } else {
          state.value = ConnectionView(
            phase: old.phase,
            runtime: old.runtime,
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
    final runtime = state.value.runtime!;
    final generation = _trafficGeneration;
    _readingTraffic = true;
    bool stillCurrent() =>
        _trafficWanted &&
        generation == _trafficGeneration &&
        state.value.runtime?.identity == runtime.identity;
    try {
      await DataMaintenance.run(() async {
        final traffic = await _readTraffic(runtime);
        if (stillCurrent()) {
          _publish(
            HostConnection(
              VpnStatus.connected,
              runtime: runtime,
              traffic: traffic,
            ),
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
          runtime: old.runtime,
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
    if (expectedConfiguration != null &&
        (await configuration).encode() != expectedConfiguration) {
      throw const ConnectionHostException('configurationChanged');
    }
    final current = await _inspect(await _known());
    final shouldStart =
        !disconnect && (connect || (affectsRuntime && current.connected));
    final shouldStop = disconnect && current.status != VpnStatus.disconnected;
    // Recheck after preceding commands finish: a disconnected editor may have
    // queued behind Connect without ever asking the user to reconnect.
    if ((shouldStart || shouldStop) && current.connected && !allowReconnect) {
      throw const ConnectionHostException('reconnectRequired');
    }
    if (!shouldStart && !shouldStop) {
      await db.connectionStateDao.commit(
        settingsJson: next.encode(),
        writeAssets: writeAssets,
      );
      _publish(current);
      return;
    }
    final cancellation = Completer<void>();
    _cancel = cancellation;
    final old = current.connected ? current.runtime : null;
    if (current.connected && old == null) {
      throw const ConnectionHostException('runtimeMetadataUnavailable');
    }
    state.value = ConnectionView(
      phase: ConnectionPhase.preparing,
      runtime: old,
      traffic: current.traffic,
    );
    bool touchedHost = false;
    try {
      _preparingNodeIds = {...?old?.nodeIds};
      final runtime = disconnect
          ? null
          : await (prepare ?? _prepare)(next, cancellation.future);
      _checkCancelled(cancellation);
      _pendingRuntime = runtime;
      var running = current;
      if (current.status != VpnStatus.disconnected) {
        touchedHost = true;
        state.value = ConnectionView(
          phase: ConnectionPhase.disconnecting,
          runtime: old,
          traffic: current.traffic,
        );
        running = await _stop();
        if (running.status != VpnStatus.disconnected) {
          throw const ConnectionHostException('stopNotConfirmed');
        }
      }
      _checkCancelled(cancellation);
      if (runtime != null) {
        touchedHost = true;
        state.value = ConnectionView(
          phase: ConnectionPhase.connecting,
          traffic: current.traffic,
        );
        running = await _start(runtime);
        _checkCancelled(cancellation);
        if (!running.connected ||
            running.runtime?.identity != runtime.identity) {
          throw const ConnectionHostException('startNotConfirmed');
        }
      }
      await db.connectionStateDao.commit(
        settingsJson: (runtime?.configuration ?? next).encode(),
        writeAssets: () async {
          await writeAssets?.call();
          _checkCancelled(cancellation);
        },
      );
      _publish(running, issue: runtime?.notice);
    } catch (error) {
      final permission = error is ConnectionHostException
          ? error.permission
          : null;
      HostConnection? failed;
      if (touchedHost) {
        try {
          failed = await _stop();
        } catch (_) {
          try {
            failed = await _inspect(await _known());
          } catch (_) {
            // The failed state remains explicit when native state is unavailable.
          }
        }
      }
      final issue = cancellation.isCompleted
          ? 'cancelled'
          : error is ConnectionHostException
          ? error.reason
          : 'changeFailed';
      if (touchedHost) {
        final status = failed?.status;
        _lastNativeStatus = status;
        _failureLatched = true;
        state.value = ConnectionView(
          phase: ConnectionPhase.failed,
          runtime: status == VpnStatus.disconnected
              ? null
              : failed?.runtime ??
                    _pendingRuntime ??
                    state.value.runtime ??
                    current.runtime,
          traffic: failed?.traffic ?? current.traffic,
          issue: issue,
          permission: permission,
        );
        _syncPolling();
      } else {
        _publish(current, issue: issue, permission: permission);
      }
      rethrow;
    } finally {
      _pendingRuntime = null;
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
      final current = await _inspect(await _known());
      state.value = ConnectionView(
        phase: ConnectionPhase.disconnecting,
        runtime: current.runtime,
        traffic: current.traffic,
      );
      _publish(await _stop());
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
    ConnectionRuntime? runtime;
    var traffic = state.value.traffic;
    _lastNativeStatus = null;
    try {
      final current = await _inspect(await _known());
      _lastNativeStatus = current.status;
      traffic = current.traffic ?? traffic;
      // The actual runtime can differ from saved settings after a failed change.
      // Keep it visible and protect its nodes without committing it.
      if (current.status != VpnStatus.disconnected) {
        runtime = current.runtime;
      }
    } catch (_) {
      // Unknown host state stays an explicit failure; retry inspects it again.
    }
    state.value = ConnectionView(
      phase: ConnectionPhase.failed,
      runtime: runtime,
      traffic: traffic,
      issue: issue,
      permission:
          permission ??
          (error is ConnectionHostException ? error.permission : null),
    );
    _failureLatched = true;
  }

  Future<void> resetTraffic() => _run(() async {
    final current = await _inspect(await _known());
    final traffic = await _resetTraffic(current.runtime);
    final previous = current.traffic ?? state.value.traffic;
    _publish(
      HostConnection(
        current.status,
        runtime: current.runtime,
        traffic: traffic ?? previous?.withTotals(uplink: 0, downlink: 0),
      ),
    );
  });

  Future<void> _run(Future<void> Function() action) =>
      DataMaintenance.run(() async {
        await initialize();
        return _commands.run((_) async {
          _failureLatched = false;
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
        current.runtime?.identity == old.runtime?.identity &&
        next != null &&
        previous?.sessionId == next.sessionId;
    // A saved 30s sample must not replace newer live counters during a status
    // refresh. Explicit resets still publish their new totals.
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
      phase: _failureLatched
          ? ConnectionPhase.failed
          : switch (current.status) {
              VpnStatus.connected => ConnectionPhase.connected,
              VpnStatus.connecting => ConnectionPhase.connecting,
              VpnStatus.disconnecting => ConnectionPhase.disconnecting,
              VpnStatus.disconnected => ConnectionPhase.disconnected,
            },
      runtime: current.status == VpnStatus.disconnected
          ? null
          : current.runtime,
      traffic: display,
      metricsAvailable:
          current.connected &&
          (retainLive || (liveTraffic && next?.available == true)),
      uploadSpeed: retainLive ? old.uploadSpeed : upload,
      downloadSpeed: retainLive ? old.downloadSpeed : download,
      issue:
          issue ??
          (current.connected && current.runtime == null
              ? 'runtimeMetadataUnavailable'
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
    _failureLatched = false;
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
