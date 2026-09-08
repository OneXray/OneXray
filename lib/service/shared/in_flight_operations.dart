import 'dart:async';

/// Owned by one module, never shared as a global business-operation gate.
/// Clearing data pauses admission and waits only for work already in progress.
final class InFlightOperations {
  final _active = <Completer<void>>{};
  bool _paused = false;

  bool get isPaused => _paused;

  Future<T> track<T>(Future<T> Function() action) async {
    if (_paused) throw StateError('Data clearing is in progress');
    final finished = Completer<void>();
    _active.add(finished);
    try {
      return await action();
    } finally {
      _active.remove(finished);
      finished.complete();
    }
  }

  Future<void> pause() {
    _paused = true;
    return Future.wait(_active.map((operation) => operation.future))
        .then((_) {});
  }

  void resume() => _paused = false;
}
