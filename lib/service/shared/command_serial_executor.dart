import 'dart:async';

final class CommandSerialExecutor {
  Future<void> _tail = Future<void>.value();
  bool _paused = false;
  int _generation = 0;

  bool get isPaused => _paused;

  /// Discard commands that have not started and wait for the current command.
  Future<void> pause() {
    _paused = true;
    _generation++;
    return _tail;
  }

  void resume() => _paused = false;

  Future<T> run<T>(Future<T> Function() command) {
    if (_paused) return Future.error(StateError('Command queue is paused'));
    final generation = _generation;
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        if (_paused || generation != _generation) {
          throw StateError('Queued command was cancelled');
        }
        completer.complete(await command());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
