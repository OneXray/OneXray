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

  test('read/watch defaults and singleton constraint', () async {
    final dao = db.connectionStateDao;
    final initial = await dao.read();
    expect(initial.id, 1);
    expect(initial.settingsJson, '{}');
    expect(initial.confirmedPlanId, isNull);
    expect(await dao.watch().first, initial);
    await expectLater(
      db.customStatement('INSERT INTO connection_state (id) VALUES (2)'),
      throwsA(anything),
    );
  });

  test(
    'settings, policy, assets and confirmed plan ID commit as one value',
    () async {
      final dao = db.connectionStateDao;
      const settings = '{"connection":{"expert":true},"policy":{"ipv6":false}}';
      await dao.commit(
        settingsJson: settings,
        confirmedPlanId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        writeAssets: () async {
          await db.coreConfigDao.insertAssetRow(_asset);
        },
      );
      final saved = await dao.watch().first;
      expect(saved.settingsJson, settings);
      expect(saved.confirmedPlanId, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      expect(
        (await db.coreConfigDao.allRawRowsWithData).single.data,
        'eyJmb28iOjF9',
      );

      await dao.commit(
        settingsJson: '{"updated":true}',
        confirmedPlanId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      final updated = await dao.read();
      expect(updated.settingsJson, '{"updated":true}');
      expect(updated.confirmedPlanId, 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
      expect(await db.select(db.connectionState).get(), [updated]);
      await dao.reset();
      expect(await dao.watch().first, await dao.read());
      expect((await dao.read()).settingsJson, '{}');
      expect((await dao.read()).confirmedPlanId, isNull);
      expect(await db.coreConfigDao.allRawRowsWithData, hasLength(1));
    },
  );

  test('asset failure leaves saved settings and plan ID intact', () async {
    final dao = db.connectionStateDao;
    await dao.commit(
      settingsJson: '{"old":true}',
      confirmedPlanId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    final before = await dao.read();
    await expectLater(
      dao.commit(
        settingsJson: '{"new":true}',
        confirmedPlanId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
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
    final before = await dao.read();
    await db.customStatement('''
      CREATE TRIGGER fail_connection_commit BEFORE UPDATE OF settings_json ON connection_state
      BEGIN SELECT RAISE(ABORT, 'test commit failure'); END
    ''');
    await expectLater(
      dao.commit(
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
