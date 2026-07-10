import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/vpn/command_serial_executor.dart';

void main() {
  test('serializes commands and advances generations', () async {
    final executor = CommandSerialExecutor();
    final firstGate = Completer<void>();
    final events = <String>[];

    final first = executor.run((generation) async {
      events.add('start-$generation');
      await firstGate.future;
      events.add('end-$generation');
      return generation;
    });
    final second = executor.run((generation) async {
      events.add('start-$generation');
      events.add('end-$generation');
      return generation;
    });

    await Future<void>.delayed(Duration.zero);
    expect(events, ['start-1']);
    firstGate.complete();

    expect(await first, 1);
    expect(await second, 2);
    expect(events, ['start-1', 'end-1', 'start-2', 'end-2']);
    expect(executor.currentGeneration, 2);
  });

  test(
    'continues after a failed command and invalidates old generations',
    () async {
      final executor = CommandSerialExecutor();

      await expectLater(
        executor.run<void>((_) async => throw StateError('failed')),
        throwsStateError,
      );
      final generation = await executor.run((generation) async => generation);
      expect(generation, 2);
      expect(executor.isCurrent(generation), isTrue);

      executor.invalidate();
      expect(executor.isCurrent(generation), isFalse);
    },
  );
}
