import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test(
    'read/watch default, singleton constraint, and exact pending cancellation',
    () async {
      final dao = db.connectionStateDao;
      final initial = await dao.read();
      expect(initial.id, 1);
      expect(initial.revision, 0);
      expect(initial.settingsJson, '{}');
      expect(initial.confirmedSnapshotJson, isNull);
      expect(await dao.watch().first, initial);
      await expectLater(
        db.customStatement('INSERT INTO connection_state (id) VALUES (2)'),
        throwsA(anything),
      );

      await dao.beginApply(0, '{"attemptId":"first"}');
      final pending = await dao.watch().first;
      expect(pending.pendingApplyJson, '{"attemptId":"first"}');
      expect(pending.revision, 0);
      expect(pending.settingsJson, '{}');
      await expectLater(
        dao.beginApply(0, '{"attemptId":"second"}'),
        throwsStateError,
      );
      await expectLater(
        dao.beginApply(1, '{"attemptId":"second"}'),
        throwsStateError,
      );
      expect(await dao.clearPending('{"attemptId":"wrong"}'), isFalse);
      expect(await dao.read(), pending);
      expect(await dao.clearPending('{"attemptId":"first"}'), isTrue);
      expect(await dao.watch().first, initial);
    },
  );

  test(
    'settings, policy, assets, snapshot and pending commit as one value',
    () async {
      final dao = db.connectionStateDao;
      await dao.beginApply(0, '{"attemptId":"apply"}');
      const settings = '{"connection":{"expert":true},"policy":{"ipv6":false}}';
      await dao.commit(
        baseRevision: 0,
        settingsJson: settings,
        confirmedSnapshotJson: '{"sessionId":"new"}',
        writeAssets: () async {
          await db.coreConfigDao.insertAssetRow(_asset);
        },
      );
      final saved = await dao.watch().first;
      expect(saved.revision, 1);
      expect(saved.settingsJson, settings);
      expect(saved.confirmedSnapshotJson, '{"sessionId":"new"}');
      expect(saved.pendingApplyJson, isNull);
      expect(
        (await db.coreConfigDao.allRawRowsWithData).single.data,
        'eyJmb28iOjF9',
      );

      var wroteAssets = false;
      await expectLater(
        dao.commit(
          baseRevision: 0,
          settingsJson: '{}',
          writeAssets: () async {
            wroteAssets = true;
          },
        ),
        throwsStateError,
      );
      expect(wroteAssets, isFalse);
      expect(await dao.read(), saved);
      await dao.reset();
      expect((await dao.watch().first).revision, 0);
      expect((await dao.read()).settingsJson, '{}');
      expect((await dao.read()).confirmedSnapshotJson, isNull);
      expect(await db.coreConfigDao.allRawRowsWithData, hasLength(1));
    },
  );

  test('asset failure leaves saved state and recovery intent intact', () async {
    final dao = db.connectionStateDao;
    await dao.commit(
      baseRevision: 0,
      settingsJson: '{"old":true}',
      confirmedSnapshotJson: '{"old":true}',
    );
    await dao.beginApply(1, '{"attemptId":"retry"}');
    final before = await dao.read();
    await expectLater(
      dao.commit(
        baseRevision: 1,
        settingsJson: '{"new":true}',
        confirmedSnapshotJson: '{"new":true}',
        writeAssets: () async {
          await db.coreConfigDao.insertAssetRow(_asset);
          throw StateError('asset write failed');
        },
      ),
      throwsStateError,
    );
    expect(await db.coreConfigDao.allRawRowsWithData, isEmpty);
    expect(await dao.read(), before);
  });

  test('state write failure also rolls back already-written assets', () async {
    final dao = db.connectionStateDao;
    await dao.beginApply(0, '{"attemptId":"apply"}');
    final before = await dao.read();
    await db.customStatement('''
      CREATE TRIGGER fail_connection_commit BEFORE UPDATE OF settings_json ON connection_state
      BEGIN SELECT RAISE(ABORT, 'test commit failure'); END
    ''');
    await expectLater(
      dao.commit(
        baseRevision: 0,
        settingsJson: '{"new":true}',
        writeAssets: () async {
          await db.coreConfigDao.insertAssetRow(_asset);
        },
      ),
      throwsA(anything),
    );
    expect(await db.coreConfigDao.allRawRowsWithData, isEmpty);
    expect(await dao.read(), before);
  });
}

final _asset = CoreConfigCompanion.insert(
  name: 'Raw',
  type: 'raw',
  tags: '',
  data: Value('eyJmb28iOjF9'),
  delay: 9000,
  subId: 0,
);
