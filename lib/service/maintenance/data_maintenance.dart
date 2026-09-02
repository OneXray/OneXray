import 'dart:async';

/// Asset writes finish before restore/clear replaces their data. New work fails
/// during maintenance rather than queuing a stale write behind the replacement.
abstract final class DataMaintenance {
  static final _running = <Completer<void>>{};
  static bool _exclusive = false;

  static Future<T> run<T>(Future<T> Function() action) async {
    if (_exclusive) {
      throw StateError('Data maintenance is in progress');
    }
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
    _exclusive = true;
    try {
      await Future.wait(_running.map((task) => task.future).toList());
      return await action();
    } finally {
      _exclusive = false;
    }
  }
}
