import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
  });

  test(
    'normal queries isolate outbound, Raw and retired asset types',
    () async {
      final dao = database.coreConfigDao;
      for (final type in ['setting', 'full', 'unknown']) {
        await dao.insertRow(_config(type));
      }
      final rawId = await dao.insertRow(_config('raw', subId: 7));
      final outboundId = await dao.insertRow(
        _config('outbound').copyWith(
          countryCode: const Value('US'),
          locationSource: const Value('probe'),
          favorite: const Value(true),
        ),
      );
      final subscriptionId = await database.subscriptionDao.insertRow(
        SubscriptionCompanion.insert(
          id: const Value(7),
          name: 'Subscription',
          url: 'https://example.com/sub',
          timestamp: DateTime.utc(2026),
          count: 1,
          expanded: true,
        ),
      );
      final subscribedId = await dao.insertRow(
        _config('outbound', subId: subscriptionId),
      );

      final configs = (await dao.allHomeNodeRows)
          .whereType<ConfigItem>()
          .toList();
      expect(configs.map((row) => row.config.id), [outboundId, subscribedId]);
      expect(configs.first.config.countryCode, 'US');
      expect(configs.first.config.locationSource, 'probe');
      expect(configs.first.config.favorite, isTrue);
      expect(
        (await dao.allHomeNodeRowsStream().first).whereType<ConfigItem>().map(
          (row) => row.config.id,
        ),
        [outboundId, subscribedId],
      );
      expect(
        (await dao.allHomeNodeRowsWithDataBySubId(0)).map((row) => row.id),
        [outboundId],
      );
      expect((await dao.allRawRowsWithData).single.id, rawId);
      expect((await dao.allRawRowsWithDataStream.first).single.id, rawId);
      expect(
        (await dao.allLocalRowsWithData).map((row) => row.id),
        unorderedEquals([outboundId, rawId]),
      );
      expect((await dao.randomConfig())!.id, outboundId);
      expect(await dao.allSettingRows, isEmpty);
      expect(await dao.allSettingRowsStream().first, isEmpty);

      // Low-level lookup remains available without reactivating retired assets.
      expect((await dao.searchRow(1))!.type, 'setting');
      await expectLater(
        dao.updateRow((await dao.searchRow(1))!),
        throwsStateError,
      );
      expect(
        await dao.updateRow(
          (await dao.searchRow(rawId))!.copyWith(type: 'outbound'),
        ),
        isFalse,
      );
      expect((await dao.searchRow(rawId))!.type, 'raw');
      await expectLater(dao.copyRow(1), throwsArgumentError);
      await expectLater(
        dao.insertAssetRows([_config('outbound'), _config('full')]),
        throwsArgumentError,
      );
      expect(await dao.allOutboundRowsWithDataBySubId(0), hasLength(1));
    },
  );

  test(
    'copy preserves metadata and encoded data without copying health',
    () async {
      final dao = database.coreConfigDao;
      final originalId = await dao.insertRow(
        _config('outbound', subId: 7).copyWith(
          data: const Value('eyJ0YWciOiJ0ZXN0In0='),
          countryCode: const Value('JP'),
          locationSource: const Value('probe'),
          lastMeasuredAt: Value(DateTime.utc(2026, 9, 2)),
          favorite: const Value(true),
          delay: const Value(42),
        ),
      );

      final copiedId = await dao.copyRow(originalId);
      final copy = (await dao.searchRow(copiedId))!;
      expect(copiedId, isNot(originalId));
      expect(copy.subId, 0);
      expect(copy.name, 'outbound config');
      expect(copy.tags, 'test-tags');
      expect(copy.data, 'eyJ0YWciOiJ0ZXN0In0=');
      expect(copy.countryCode, 'JP');
      expect(copy.locationSource, 'probe');
      expect(copy.favorite, isTrue);
      expect(copy.delay, PingDelayConstants.unknown);
      expect(copy.lastMeasuredAt, isNull);
      expect((await dao.searchRow(originalId))!.delay, 42);
    },
  );

  test(
    'Raw additions enforce 0/2/3 limits atomically across mixed batches',
    () async {
      final dao = database.coreConfigDao;
      expect(await dao.allRawRowsWithData, isEmpty);
      expect(await dao.insertAssetRows([_config('raw'), _config('raw')]), 2);
      await expectLater(
        dao.insertAssetRows([
          _config('outbound'),
          _config('raw'),
          _config('raw'),
        ]),
        throwsStateError,
      );
      expect(await dao.allRawRowsWithData, hasLength(2));
      expect(await dao.allOutboundRowsWithDataBySubId(0), isEmpty);

      final thirdId = await dao.insertAssetRow(_config('raw'));
      await expectLater(dao.insertAssetRow(_config('raw')), throwsStateError);
      await expectLater(dao.copyRow(thirdId), throwsStateError);
      expect(await dao.allRawRowsWithData, hasLength(3));
    },
  );

  test(
    'restored excess Raw stays editable and deletable until additions fit',
    () async {
      final dao = database.coreConfigDao;
      await dao.insertRows(List.generate(4, (_) => _config('raw')));
      final restored = await dao.allRawRowsWithData;
      expect(restored, hasLength(4));
      await expectLater(dao.insertAssetRow(_config('raw')), throwsStateError);
      await expectLater(dao.copyRow(restored.first.id), throwsStateError);
      expect(
        await dao.updateRow(
          restored.first.copyWith(
            name: 'Edited',
            data: const Value('ZWRpdA=='),
          ),
        ),
        isTrue,
      );
      expect((await dao.searchRow(restored.first.id))!.data, 'ZWRpdA==');
      await dao.deleteRow(restored[3]);
      await dao.deleteRow(restored[2]);
      expect(await dao.allRawRowsWithData, hasLength(2));
      await dao.copyRow(restored.first.id);
      expect(await dao.allRawRowsWithData, hasLength(3));
    },
  );

  test(
    'custom routing enforces three profiles without limiting edits',
    () async {
      final dao = database.customRoutingProfilesDao;
      for (var index = 0; index < 2; index++) {
        await dao.insertRow(_routingProfile('Profile $index'));
      }
      final additions = await Future.wait([
        for (final name in ['Third', 'Fourth'])
          dao
              .insertRow(_routingProfile(name))
              .then(
                (_) => true,
                onError: (Object error, StackTrace stackTrace) {
                  expect(error, isStateError);
                  return false;
                },
              ),
      ]);
      expect(additions.where((added) => added), hasLength(1));
      final profiles = await dao.allRows;
      expect(profiles, hasLength(3));
      expect(profiles.first.data, 'eyJvdXRib3VuZHMiOlt7fV19');
      expect(
        await dao.updateRow(profiles.first.copyWith(name: 'Edited')),
        isTrue,
      );
      expect((await dao.searchRow(profiles.first.id))!.name, 'Edited');
      await dao.deleteRow(profiles.last.id);
      await dao.insertRow(_routingProfile('Replacement'));
      expect(await dao.allRowsStream.first, hasLength(3));
      expect(await dao.clear(), 3);
      expect(await dao.allRows, isEmpty);
    },
  );
}

CoreConfigCompanion _config(String type, {int subId = 0}) =>
    CoreConfigCompanion.insert(
      name: '$type config',
      type: type,
      tags: 'test-tags',
      data: const Value('eyJ0YWciOiJ0ZXN0In0='),
      delay: PingDelayConstants.unknown,
      subId: subId,
    );

CustomRoutingProfilesCompanion _routingProfile(String name) =>
    CustomRoutingProfilesCompanion.insert(
      name: name,
      data: 'eyJvdXRib3VuZHMiOlt7fV19',
    );
