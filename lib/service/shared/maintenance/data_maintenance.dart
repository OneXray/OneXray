import 'dart:async';

/// Clear-data only. Ordinary tasks run concurrently; file publication uses
/// its own coordination instead of closing this gate.
abstract final class DataMaintenance {
  static final _running = <Completer<void>>{};
  static final _scopeKey = Object();
  static bool _exclusive = false;
  static Completer<void>? _exclusiveFinished;

  /// Descendants of registered tasks may finish after replacement is requested.
  /// Each child is tracked too, including unawaited queued probes.
  static Future<T> run<T>(
    Future<T> Function() action, {
    bool wait = false,
  }) async {
    while (_exclusive && !_running.contains(Zone.current[_scopeKey])) {
      if (!wait) throw StateError('Data maintenance is in progress');
      await _exclusiveFinished!.future;
    }
    return _track(action);
  }

  static Future<T> _track<T>(Future<T> Function() action) async {
    final finished = Completer<void>();
    _running.add(finished);
    try {
      return await runZoned(action, zoneValues: {_scopeKey: finished});
    } finally {
      _running.remove(finished);
      finished.complete();
    }
  }

  static Future<T> exclusive<T>(Future<T> Function() action) async {
    if (_exclusive) {
      throw StateError('Data maintenance is in progress');
    }
    return _runExclusive(action);
  }

  static Future<T> _runExclusive<T>(Future<T> Function() action) async {
    final finished = Completer<void>();
    _exclusive = true;
    _exclusiveFinished = finished;
    try {
      while (_running.isNotEmpty) {
        await Future.wait(_running.map((task) => task.future).toList());
      }
      return await action();
    } finally {
      _exclusive = false;
      _exclusiveFinished = null;
      finished.complete();
    }
  }
}
