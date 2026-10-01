import 'dart:async';

import 'package:onexray/core/ffi/desktop_core_exit.dart';
import 'package:onexray/core/pigeon/messages.g.dart';

/// Owns passive exit watches; every PID read still queries the operating system.
class CoreProcessMonitor {
  final Future<Set<int>> Function() _discoverPids;
  final DesktopCoreExitWatch Function(int) _watchExit;
  final bool Function() _canPublish;
  final Future<void> Function(VpnStatus) _notify;
  final void Function(Object) _notifyError;
  final _exitWatches = <int, DesktopCoreExitWatch>{};
  int _watchGeneration = 0;
  int _queryGeneration = 0;
  bool _observing = false;

  CoreProcessMonitor({
    required this._discoverPids,
    required this._watchExit,
    required this._canPublish,
    required this._notify,
    required this._notifyError,
  });

  Future<void> observe() async {
    _observing = true;
    final query = readPids();
    final generation = _queryGeneration;
    try {
      await query;
    } catch (_) {
      if (generation == _queryGeneration) dispose();
      rethrow;
    }
  }

  void dispose() {
    _observing = false;
    clearWatches();
  }

  Future<Set<int>> readPids() async {
    // One-shot reads supersede exit queries before either read finishes.
    final generation = ++_queryGeneration;
    final pids = await _discoverPids();
    if (_observing && generation == _queryGeneration) _syncWatches(pids);
    return pids;
  }

  Future<bool> waitForExit(int pid) => _watch(pid).exited;

  void invalidateQueries() => _queryGeneration++;

  void clearWatches() {
    _watchGeneration++;
    invalidateQueries();
    for (final watch in _exitWatches.values) {
      watch.cancel();
    }
    _exitWatches.clear();
  }

  void _syncWatches(Set<int> pids) {
    for (final pid in _exitWatches.keys.toList()) {
      if (!pids.contains(pid)) _exitWatches.remove(pid)?.cancel();
    }
    for (final pid in pids) {
      _watch(pid);
    }
  }

  DesktopCoreExitWatch _watch(int pid) {
    final existing = _exitWatches[pid];
    if (existing != null) return existing;
    final watch = _watchExit(pid);
    final generation = _watchGeneration;
    int? queryGeneration;
    _exitWatches[pid] = watch;
    unawaited(
      watch.exited
          .then((exited) async {
            if (!identical(_exitWatches[pid], watch)) return;
            _exitWatches.remove(pid);
            if (!exited || !_observing || !_canPublish()) return;
            final query = readPids();
            queryGeneration = _queryGeneration;
            final pids = await query;
            if (_isCurrent(generation, queryGeneration)) {
              await _notify(
                pids.isNotEmpty ? VpnStatus.connected : VpnStatus.disconnected,
              );
            }
          })
          .catchError((Object error) {
            if (identical(_exitWatches[pid], watch)) {
              _exitWatches.remove(pid)?.cancel();
            }
            if (_isCurrent(generation, queryGeneration)) _notifyError(error);
          }),
    );
    return watch;
  }

  bool _isCurrent(int watchGeneration, int? queryGeneration) =>
      _observing &&
      _canPublish() &&
      watchGeneration == _watchGeneration &&
      (queryGeneration == null || queryGeneration == _queryGeneration);
}
