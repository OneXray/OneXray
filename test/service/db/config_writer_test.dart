import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/db/config_writer.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
  });

  test(
    'asset writer preserves already encoded payloads and returns new IDs',
    () async {
      final result = await ConfigWriter.writeRowsInTransaction(database, [
        _config('outbound'),
        _config('raw'),
      ], null);
      expect(result.count, 2);
      expect(result.ids.toSet(), hasLength(2));
      for (final id in result.ids) {
        expect(
          (await database.coreConfigDao.searchRow(id))!.data,
          'eyJ0YWciOiJhIn0=',
        );
      }
      expect(
        await ConfigWriter.writeRowsBatchInTransaction(database, [
          _config('outbound'),
        ], 7),
        1,
      );
      expect(
        (await database.coreConfigDao.allOutboundRowsWithDataBySubId(7))
            .single
            .data,
        'eyJ0YWciOiJhIn0=',
      );
    },
  );

  test(
    'asset writer rolls back entire mixed batches on Raw limit or old type',
    () async {
      await database.coreConfigDao.insertRows([_config('raw'), _config('raw')]);
      await expectLater(
        ConfigWriter.writeRowsInTransaction(database, [
          _config('raw'),
          _config('outbound'),
          _config('raw'),
        ], null),
        throwsStateError,
      );
      expect(await database.coreConfigDao.allRawRowsWithData, hasLength(2));
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(0),
        isEmpty,
      );
      await expectLater(
        ConfigWriter.writeRowsInTransaction(database, [
          _config('outbound'),
          _config('full'),
        ], null),
        throwsArgumentError,
      );
      expect(
        await database.coreConfigDao.allOutboundRowsWithDataBySubId(0),
        isEmpty,
      );
    },
  );
}

CoreConfigCompanion _config(String type) => CoreConfigCompanion.insert(
  name: 'Asset',
  type: type,
  tags: '',
  data: const Value('eyJ0YWciOiJhIn0='),
  delay: 0,
  subId: 0,
);
