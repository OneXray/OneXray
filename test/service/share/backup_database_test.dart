import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/share/backup_database.dart';
import 'package:onexray/service/share/backup_model.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  test(
    'v5 round trips retained assets, IDs, metadata, and encoded data',
    () async {
      await _seedAssets(database);
      await database.connectionStateDao.commit(
        settingsJson: '{"connection":{"rawId":30}}',
        confirmedPlanId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final before = await BackupDatabaseContents.read(database);
      final payload = _roundTrip(before);

      expect(payload.coreConfigs, hasLength(6));
      expect(payload.coreConfigs.any((row) => row.type == 'setting'), isFalse);
      await payload.restore(database);
      final after = await BackupDatabaseContents.read(database);

      expect(_json(after), _json(before, resetMeasurements: true));
      final nodes = await database.coreConfigDao.allRawRowsWithData;
      expect(nodes, hasLength(4));
      expect(nodes.singleWhere((row) => row.id == 33).data, 'not base64!');
      expect(nodes.singleWhere((row) => row.id == 32).subId, 999);
      final cached = await database.coreConfigDao.searchRow(2);
      expect(cached!.subId, 7);
      expect(cached.favorite, isTrue);
      expect(cached.countryCode, 'JP');
      expect(cached.delay, PingDelayConstants.unknown);
      final subscription = (await database.subscriptionDao.allRows).single;
      expect(subscription.id, 7);
      expect(subscription.count, 1);
      expect(subscription.ageSecretKey, 'AGE-SECRET-KEY-TEST');
      expect(subscription.agePublicKey, 'age1test');
      expect((await database.routingProfileDao.allRows).single.id, 8);
      expect(await database.coreConfigDao.searchRow(99), isNull);
      final reset = await database.connectionStateDao.read();
      expect(reset.settingsJson, '{}');
      expect(reset.confirmedPlanId, isNull);
    },
  );

  for (final version in [3, 4]) {
    test('v$version restores all legacy Raw and skips retired types', () async {
      await _seedAssets(database);
      final payload = BackupDatabaseContents(
        version: version,
        coreConfigs: [
          for (var i = 0; i < 4; i++)
            BackupCoreConfigJson('Raw $i', 'raw', '', 'old-base64-$i'),
          const BackupCoreConfigJson('Node', 'outbound', 'VLESS', null),
          const BackupCoreConfigJson(null, 'setting', null, null),
          const BackupCoreConfigJson(null, 'full', null, null),
          const BackupCoreConfigJson(null, 'unknown', null, null),
        ],
        subscriptions: [
          BackupSubscriptionJson(
            'Legacy subscription',
            'https://example.com/sub',
            version == 4 ? 'AGE-SECRET-KEY-TEST' : null,
            version == 4 ? 'age1test' : null,
            1000,
            true,
          ),
        ],
        geoDataList: const [],
        routingProfiles: const [],
      );

      expect(payload.skippedCoreConfigCount, 3);
      final subscriptions = await payload.restore(database);

      final raw = await database.coreConfigDao.allRawRowsWithData;
      expect(raw, hasLength(4));
      expect(raw.map((row) => row.data), [
        for (var i = 0; i < 4; i++) 'old-base64-$i',
      ]);
      expect(raw.every((row) => row.subId == 0 && !row.favorite), isTrue);
      expect(raw.every((row) => row.countryCode == null), isTrue);
      expect(subscriptions.single.count, 0);
      expect(
        subscriptions.single.ageSecretKey,
        version == 4 ? 'AGE-SECRET-KEY-TEST' : null,
      );
      expect(await database.routingProfileDao.allRows, isEmpty);
      expect(await database.geoDataDao.allRows, isEmpty);
    });
  }

  test('rejects four Custom profiles before changing current assets', () async {
    await _seedAssets(database);
    final before = await BackupDatabaseContents.read(database);
    final payload = BackupDatabaseContents(
      version: 5,
      coreConfigs: before.coreConfigs,
      subscriptions: before.subscriptions,
      geoDataList: before.geoDataList,
      routingProfiles: [
        for (var id = 1; id <= 4; id++)
          BackupRoutingProfileJson(id, 'Custom $id', 'encoded-$id'),
      ],
    );

    await expectLater(payload.restore(database), throwsFormatException);
    expect(_json(await BackupDatabaseContents.read(database)), _json(before));
  });

  test(
    'restore rejects uneditable Custom fields without changing assets',
    () async {
      await _seedAssets(database);
      final before = await BackupDatabaseContents.read(database);
      final payload = BackupDatabaseContents(
        version: 5,
        coreConfigs: before.coreConfigs,
        subscriptions: before.subscriptions,
        geoDataList: before.geoDataList,
        routingProfiles: [
          BackupRoutingProfileJson(
            8,
            'Invalid',
            base64Encode(
              utf8.encode('{"outbounds":[{}],"dns":{"servers":["localhost"]}}'),
            ),
          ),
        ],
      );
      await expectLater(payload.restore(database), throwsFormatException);
      expect(_json(await BackupDatabaseContents.read(database)), _json(before));
    },
  );

  test(
    'preserves legacy orphan outbound ID, subId, and encoded data',
    () async {
      await _seedAssets(database);
      final before = await BackupDatabaseContents.read(database);
      final payload = BackupDatabaseContents(
        version: 5,
        coreConfigs: before.coreConfigs,
        subscriptions: const [],
        geoDataList: before.geoDataList,
        routingProfiles: before.routingProfiles,
      );

      await _roundTrip(payload).restore(database);
      final restored = await BackupDatabaseContents.read(database);
      expect(_json(restored), _json(payload, resetMeasurements: true));
      final orphan = await database.coreConfigDao.searchRow(2);
      final original = before.coreConfigs.singleWhere((row) => row.id == 2);
      expect(orphan!.subId, 7);
      expect(orphan.data, original.data);
      expect(await database.subscriptionDao.allRows, isEmpty);
    },
  );

  test('rejects duplicate IDs and incomplete Age key pairs', () async {
    await _seedAssets(database);
    final before = await BackupDatabaseContents.read(database);
    final duplicate = BackupDatabaseContents(
      version: 5,
      coreConfigs: [...before.coreConfigs, before.coreConfigs.first],
      subscriptions: before.subscriptions,
      geoDataList: before.geoDataList,
      routingProfiles: before.routingProfiles,
    );
    expect(duplicate.validate, throwsFormatException);
    final incompleteAge = BackupDatabaseContents(
      version: 4,
      coreConfigs: const [],
      subscriptions: const [
        BackupSubscriptionJson(
          'Legacy',
          'https://example.com',
          'secret',
          null,
          1,
          true,
        ),
      ],
      geoDataList: const [],
      routingProfiles: const [],
    );
    expect(incompleteAge.validate, throwsFormatException);
  });

  test(
    'still rejects a negative subId without changing current assets',
    () async {
      await _seedAssets(database);
      final before = await BackupDatabaseContents.read(database);
      final invalid = BackupDatabaseContents(
        version: 5,
        coreConfigs: const [
          BackupCoreConfigJson(
            'Node',
            'outbound',
            '',
            null,
            id: 1,
            subId: -1,
            delay: 0,
            favorite: false,
          ),
        ],
        subscriptions: const [],
        geoDataList: const [],
        routingProfiles: const [],
      );
      await expectLater(invalid.restore(database), throwsFormatException);
      expect(_json(await BackupDatabaseContents.read(database)), _json(before));
    },
  );

  test(
    'restore failure rolls all tables back after replacement starts',
    () async {
      await _seedAssets(database);
      await database.connectionStateDao.commit(
        settingsJson: '{"old":true}',
        confirmedPlanId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
      final stateBefore = await database.connectionStateDao.read();
      final before = await BackupDatabaseContents.read(database);
      await database.customStatement('''
      CREATE TRIGGER fail_custom_restore BEFORE INSERT ON routing_profile
      BEGIN SELECT RAISE(ABORT, 'fixture restore failure'); END
    ''');

      await expectLater(before.restore(database), throwsA(isA<Exception>()));
      expect(_json(await BackupDatabaseContents.read(database)), _json(before));
      expect(await database.coreConfigDao.searchRow(99), isNotNull);
      expect(await database.connectionStateDao.read(), stateBefore);
    },
  );

  test('rejects unsafe, reserved, or duplicate GeoData names', () {
    for (final names in [
      ['../outside'],
      [r'..\outside'],
      ['geoip'],
      ['GEOSITE'],
      ['rules', 'RULES'],
    ]) {
      final payload = BackupDatabaseContents(
        version: 4,
        coreConfigs: const [],
        subscriptions: const [],
        geoDataList: [
          for (final name in names)
            BackupGeoDataJson(
              name,
              'domain',
              'https://example.com/rules',
              1,
              1,
              1,
            ),
        ],
        routingProfiles: const [],
      );
      expect(payload.validate, throwsFormatException);
    }
  });
}

Future<void> _seedAssets(AppDatabase database) async {
  await database.subscriptionDao.insertRow(
    SubscriptionCompanion.insert(
      id: const Value(7),
      name: 'Subscription',
      url: 'https://example.com/sub',
      ageSecretKey: const Value('AGE-SECRET-KEY-TEST'),
      agePublicKey: const Value('age1test'),
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      count: 1,
      expanded: true,
    ),
  );
  for (final id in [1, 2, 30, 31, 32, 33, 99]) {
    await database.coreConfigDao.insertRow(
      CoreConfigCompanion.insert(
        id: Value(id),
        name: '节点😀 $id',
        type: id == 99
            ? 'setting'
            : id >= 30
            ? 'raw'
            : 'outbound',
        tags: 'VLESS | XHTTP | TLS',
        data: Value(
          id == 33
              ? 'not base64!'
              : base64Encode(utf8.encode('{"tag":"节点$id"}')),
        ),
        delay: 123,
        subId: id == 2
            ? 7
            : id == 32
            ? 999
            : 0,
        countryCode: id == 2 ? const Value('JP') : const Value.absent(),
        favorite: Value(id == 2),
      ),
    );
  }
  await database.routingProfileDao.insertRow(
    RoutingProfileCompanion.insert(
      id: const Value(8),
      name: 'Custom',
      data: base64Encode(utf8.encode('{"outbounds":[{}]}')),
    ),
  );
  await database.geoDataDao.insertRow(
    GeoDataCompanion.insert(
      id: const Value(9),
      name: 'custom-rules',
      type: 'domain',
      url: 'https://example.com/rules.dat',
      timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
      categoryCount: 2,
      ruleCount: 20,
    ),
  );
}

BackupDatabaseContents _roundTrip(BackupDatabaseContents value) =>
    BackupDatabaseContents(
      version: value.version,
      coreConfigs: value.coreConfigs
          .map((row) => BackupCoreConfigJson.fromJson(row.toJson()))
          .toList(),
      subscriptions: value.subscriptions
          .map((row) => BackupSubscriptionJson.fromJson(row.toJson()))
          .toList(),
      geoDataList: value.geoDataList
          .map((row) => BackupGeoDataJson.fromJson(row.toJson()))
          .toList(),
      routingProfiles: value.routingProfiles
          .map((row) => BackupRoutingProfileJson.fromJson(row.toJson()))
          .toList(),
    );

Map<String, Object> _json(
  BackupDatabaseContents value, {
  bool resetMeasurements = false,
}) => {
  'core': [
    for (final row in value.coreConfigs)
      {
        ...row.toJson(),
        if (resetMeasurements && row.type == 'outbound')
          'delay': PingDelayConstants.unknown,
      },
  ],
  'subscriptions': value.subscriptions.map((row) => row.toJson()).toList(),
  'geodata': value.geoDataList.map((row) => row.toJson()).toList(),
  'custom': value.routingProfiles.map((row) => row.toJson()).toList(),
};
