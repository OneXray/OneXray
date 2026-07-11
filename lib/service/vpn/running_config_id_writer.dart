typedef RunningConfigIdPersist = Future<void> Function(int value);
typedef RunningConfigIdApply = void Function(int value);
typedef RunningConfigIdRead = int Function();
typedef RunningConfigGenerationCheck = bool Function(int generation);

final class RunningConfigIdWriter {
  final RunningConfigIdPersist _persist;
  final RunningConfigIdApply _apply;
  final RunningConfigIdRead _readCurrent;
  final RunningConfigGenerationCheck _isCurrent;

  Future<void> _tail = Future<void>.value();

  factory RunningConfigIdWriter({
    required RunningConfigIdPersist persist,
    required RunningConfigIdApply apply,
    required RunningConfigIdRead readCurrent,
    required RunningConfigGenerationCheck isCurrent,
  }) => RunningConfigIdWriter._(persist, apply, readCurrent, isCurrent);

  RunningConfigIdWriter._(
    this._persist,
    this._apply,
    this._readCurrent,
    this._isCurrent,
  );

  Future<void> write(int value, int generation) {
    final operation = _tail.then((_) async {
      if (!_isCurrent(generation)) {
        return;
      }
      await _persist(value);
      if (!_isCurrent(generation)) {
        await _persist(_readCurrent());
        return;
      }
      _apply(value);
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }
}
