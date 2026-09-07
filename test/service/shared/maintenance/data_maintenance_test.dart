import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/maintenance/data_maintenance.dart';

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
    'registered work can finish nested writes after replacement is requested',
    () async {
      final release = Completer<void>();
      var restored = false;
      var written = false;
      final oldWrite = DataMaintenance.run(() async {
        await release.future;
        await DataMaintenance.run(() async => written = true);
      });
      final restore = DataMaintenance.exclusive(() async {
        expect(written, isTrue);
        restored = true;
      });
      release.complete();

      await oldWrite;
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

  test('an expired task scope cannot admit work during replacement', () async {
    final releaseLateWork = Completer<void>();
    final releaseRestore = Completer<void>();
    late Future<void> lateWork;
    await DataMaintenance.run(() async {
      lateWork = releaseLateWork.future.then(
        (_) => DataMaintenance.run(() async => fail('Stale scope')),
      );
    });
    final restore = DataMaintenance.exclusive(() => releaseRestore.future);
    final rejected = expectLater(lateWork, throwsStateError);
    try {
      releaseLateWork.complete();
      await rejected;
    } finally {
      releaseRestore.complete();
      await restore;
    }
  });

  test(
    'replacement also drains children scheduled by an admitted import',
    () async {
      final releaseImport = Completer<void>();
      final releaseProbe = Completer<void>();
      late Future<void> probe;
      var restored = false;
      final importing = DataMaintenance.run(() async {
        await releaseImport.future;
        probe = DataMaintenance.run(() => releaseProbe.future);
      });
      final restore = DataMaintenance.exclusive(() async => restored = true);
      releaseImport.complete();
      await importing;
      await Future<void>.delayed(Duration.zero);
      expect(restored, isFalse);
      releaseProbe.complete();
      await probe;
      await restore.timeout(const Duration(seconds: 1));
      expect(restored, isTrue);
    },
  );
}
