import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/vpn/running_config_id_writer.dart';

void main() {
  test(
    'restores the current ID when generation changes during a write',
    () async {
      var currentGeneration = 1;
      var currentId = 0;
      var persistedId = 0;
      final writes = <int>[];
      final writeStarted = Completer<void>();
      final allowWriteToComplete = Completer<void>();

      final writer = RunningConfigIdWriter(
        persist: (value) async {
          persistedId = value;
          writes.add(value);
          if (value == 1 && !writeStarted.isCompleted) {
            writeStarted.complete();
            await allowWriteToComplete.future;
          }
        },
        apply: (value) => currentId = value,
        readCurrent: () => currentId,
        isCurrent: (generation) => generation == currentGeneration,
      );

      final staleWrite = writer.write(1, 1);
      await writeStarted.future;
      currentGeneration = 2;
      allowWriteToComplete.complete();
      await staleWrite;

      expect(writes, [1, 0]);
      expect(persistedId, 0);
      expect(currentId, 0);

      await writer.write(2, 2);
      expect(persistedId, 2);
      expect(currentId, 2);
    },
  );

  test('skips a queued write after its generation becomes stale', () async {
    var currentGeneration = 1;
    var currentId = 0;
    final writes = <int>[];
    final writeStarted = Completer<void>();
    final allowWriteToComplete = Completer<void>();

    final writer = RunningConfigIdWriter(
      persist: (value) async {
        writes.add(value);
        if (value == 1 && !writeStarted.isCompleted) {
          writeStarted.complete();
          await allowWriteToComplete.future;
        }
      },
      apply: (value) => currentId = value,
      readCurrent: () => currentId,
      isCurrent: (generation) => generation == currentGeneration,
    );

    final first = writer.write(1, 1);
    final queued = writer.write(2, 1);
    await writeStarted.future;
    currentGeneration = 2;
    allowWriteToComplete.complete();
    await Future.wait([first, queued]);

    expect(writes, [1, 0]);
    expect(currentId, 0);
  });
}
