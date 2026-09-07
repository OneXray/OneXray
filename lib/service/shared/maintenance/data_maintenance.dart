import 'dart:async';

/// Asset writes finish before restore/clear replaces their data. New work fails
/// during maintenance rather than queuing a stale write behind the replacement.
abstract final class DataMaintenance {
  static final _running = <Completer<void>>{};
  static bool _exclusive = false;
  static Completer<void>? _exclusiveFinished;

  static Future<T> run<T>(Future<T> Function() action) async {
    if (_exclusive) {
      throw StateError('Data maintenance is in progress');
    }
    return _track(action);
  }

  /// Cleanup must not be dropped when restore/clear is already running. Wait
  /// for that owner, then replace files without overlapping active readers.
  static Future<T> cleanup<T>(Future<T> Function() action) async {
    while (true) {
      final exclusive = _exclusiveFinished;
      if (exclusive == null) return _runExclusive(action);
      await exclusive.future;
    }
  }

  static Future<T> _track<T>(Future<T> Function() action) async {
    final finished = Completer<void>();
    _running.add(finished);
    try {
      return await action();
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
      await Future.wait(_running.map((task) => task.future).toList());
      return await action();
    } finally {
      _exclusive = false;
      _exclusiveFinished = null;
      finished.complete();
    }
  }
}
