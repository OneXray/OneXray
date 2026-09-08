import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/command_serial_executor.dart';

void main() {
  test('serializes commands and returns their results', () async {
    final executor = CommandSerialExecutor();
    final firstGate = Completer<void>();
    final events = <String>[];

    final first = executor.run(() async {
      events.add('start-1');
      await firstGate.future;
      events.add('end-1');
      return 1;
    });
    final second = executor.run(() async {
      events.add('start-2');
      events.add('end-2');
      return 2;
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['start-1']);
    firstGate.complete();

    expect(await first, 1);
    expect(await second, 2);
    expect(events, ['start-1', 'end-1', 'start-2', 'end-2']);
  });

  test('continues after a failed command', () async {
    final executor = CommandSerialExecutor();

    await expectLater(
      executor.run<void>(() async => throw StateError('failed')),
      throwsStateError,
    );
    expect(await executor.run(() async => 2), 2);
  });

  test('independent queues do not block each other', () async {
    final first = CommandSerialExecutor();
    final second = CommandSerialExecutor();
    final release = Completer<void>();
    final pending = first.run(() => release.future);
    expect(await second.run(() async => 1), 1);
    release.complete();
    await pending;
  });

  test(
    'pause cancels pending work and drains only the running command',
    () async {
      final queue = CommandSerialExecutor();
      final release = Completer<void>();
      final started = Completer<void>();
      final first = queue.run(() async {
        started.complete();
        await release.future;
        return 1;
      });
      await started.future;
      final second = expectLater(
        queue.run(() async => fail('Pending command must not run')),
        throwsStateError,
      );
      var idle = false;
      final pausing = queue.pause().then((_) => idle = true);
      await expectLater(queue.run(() async => 3), throwsStateError);
      expect(idle, isFalse);
      release.complete();
      expect(await first, 1);
      await second;
      await pausing;
      queue.resume();
      expect(await queue.run(() async => 4), 4);
    },
  );
}
