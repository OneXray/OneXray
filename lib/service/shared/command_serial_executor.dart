import 'dart:async';

final class CommandSerialExecutor {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() command) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await command());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
