import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';

void main() {
  test(
    'restore waits for old writes and rejects new work immediately',
    () async {
      final release = Completer<void>();
      final order = <String>[];
      var data = 'original';
      final oldWrite = DataMaintenance.run(() async {
        await release.future;
        data = 'old download';
        order.add('old write finished');
      });
      final restore = DataMaintenance.exclusive(() async {
        data = 'restored';
        order.add('restore');
      });

      await expectLater(
        DataMaintenance.run(() async => data = 'new write'),
        throwsStateError,
      );
      expect(order, isEmpty);
      release.complete();
      await oldWrite;
      await restore;
      expect(order, ['old write finished', 'restore']);
      expect(data, 'restored');
      expect(await DataMaintenance.run(() async => data), 'restored');
    },
  );

  test(
    'nested work rejected during maintenance lets its parent finish',
    () async {
      final release = Completer<void>();
      var restored = false;
      final oldWrite = DataMaintenance.run(() async {
        await release.future;
        await DataMaintenance.run(() async => fail('must not run nested work'));
      });
      final oldFailure = expectLater(oldWrite, throwsStateError);
      final restore = DataMaintenance.exclusive(() async => restored = true);
      release.complete();

      await oldFailure;
      await restore.timeout(const Duration(seconds: 1));
      expect(restored, isTrue);
    },
  );

  test(
    'maintenance rejects a second owner and always releases after failure',
    () async {
      final release = Completer<void>();
      final restore = DataMaintenance.exclusive<void>(() async {
        await release.future;
        throw StateError('restore failed');
      });
      final failure = expectLater(restore, throwsStateError);
      await expectLater(
        DataMaintenance.exclusive(() async {}),
        throwsStateError,
      );
      release.complete();
      await failure;

      expect(await DataMaintenance.run(() async => 7), 7);
      expect(await DataMaintenance.exclusive(() async => 8), 8);
    },
  );

  test('cleanup waits for maintenance instead of being dropped', () async {
    final release = Completer<void>();
    final order = <String>[];
    final maintenance = DataMaintenance.exclusive(() async {
      order.add('maintenance started');
      await release.future;
      order.add('maintenance finished');
    });
    final cleanup = DataMaintenance.cleanup(() async {
      order.add('cleanup');
    });

    await Future<void>.delayed(Duration.zero);
    expect(order, ['maintenance started']);
    release.complete();
    await maintenance;
    await cleanup;
    expect(order, ['maintenance started', 'maintenance finished', 'cleanup']);
  });

  test('cleanup waits for active readers and blocks new readers', () async {
    final releaseReader = Completer<void>();
    final order = <String>[];
    final reader = DataMaintenance.run(() async {
      order.add('reader started');
      await releaseReader.future;
      order.add('reader finished');
    });
    final cleanup = DataMaintenance.cleanup(() async {
      order.add('cleanup');
    });
    await Future<void>.delayed(Duration.zero);
    expect(order, ['reader started']);
    await expectLater(DataMaintenance.run(() async {}), throwsStateError);
    releaseReader.complete();
    await reader;
    await cleanup;
    expect(order, ['reader started', 'reader finished', 'cleanup']);
  });
}
