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
    final dao = db.connectionConfigDao;
    final initial = await dao.read();
    expect(initial.id, 1);
    expect(initial.configurationJson, '{}');
    expect(await dao.watch().first, initial);
    await expectLater(
      db.customStatement('INSERT INTO connection_config (id) VALUES (2)'),
      throwsA(anything),
    );
  });

  test('connection configuration and assets commit as one value', () async {
    final dao = db.connectionConfigDao;
    const configuration =
        '{"connection":{"expert":true},"policy":{"ipv6":false}}';
    await dao.commit(
      configurationJson: configuration,
      writeAssets: () async {
        await db.coreConfigDao.insertAssetRow(_asset);
      },
    );
    final saved = await dao.watch().first;
    expect(saved.configurationJson, configuration);
    expect(
      (await db.coreConfigDao.allRawRowsWithData).single.data,
      'eyJmb28iOjF9',
    );

    await dao.commit(configurationJson: '{"updated":true}');
    final updated = await dao.read();
    expect(updated.configurationJson, '{"updated":true}');
    expect(await db.select(db.connectionConfig).get(), [updated]);
    await dao.reset();
    expect(await dao.watch().first, await dao.read());
    expect((await dao.read()).configurationJson, '{}');
    expect(await db.coreConfigDao.allRawRowsWithData, hasLength(1));
  });

  test('asset failure leaves saved configuration intact', () async {
    final dao = db.connectionConfigDao;
    await dao.commit(configurationJson: '{"old":true}');
    final before = await dao.read();
    await expectLater(
      dao.commit(
        configurationJson: '{"new":true}',
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

  test(
    'configuration write failure rolls back already-written assets',
    () async {
      final dao = db.connectionConfigDao;
      final before = await dao.read();
      await db.customStatement('''
      CREATE TRIGGER fail_connection_commit BEFORE UPDATE OF configuration_json ON connection_config
      BEGIN SELECT RAISE(ABORT, 'test commit failure'); END
    ''');
      await expectLater(
        dao.commit(
          configurationJson: '{"new":true}',
          writeAssets: () async {
            await db.coreConfigDao.insertAssetRow(_asset);
          },
        ),
        throwsA(anything),
      );
      expect(await db.coreConfigDao.allRawRowsWithData, isEmpty);
      expect(await dao.read(), before);
    },
  );
}

final _asset = CoreConfigCompanion.insert(
  name: 'Raw',
  type: 'raw',
  tags: '',
  data: Value('eyJmb28iOjF9'),
  delay: 9000,
  subId: 0,
);
