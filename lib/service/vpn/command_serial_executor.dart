import 'dart:async';

final class CommandSerialExecutor {
  Future<void> _tail = Future<void>.value();
  var _generation = 0;

  int get currentGeneration => _generation;

  bool isCurrent(int generation) => generation == _generation;

  void invalidate() {
    _generation++;
  }

  Future<T> run<T>(Future<T> Function(int generation) command) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      final generation = ++_generation;
      try {
        completer.complete(await command(generation));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
