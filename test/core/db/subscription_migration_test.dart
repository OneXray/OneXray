import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/upgrade_snapshot.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  test('an interrupted empty first creation retries, but an unknown populated DB does not', () async {
    final directory = await _fixtureDirectory('onexray-empty-db-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/db.sqlite');
    sqlite.sqlite3.open(file.path).close();
    var stopCalled = false;
    expect(
      await prepareUpgradeSnapshot(
        file,
        stopRunning: () async {
          stopCalled = true;
        },
      ),
      null,
    );
    expect(stopCalled, isFalse);
    final unknown = sqlite.sqlite3.open(file.path);
    unknown.execute('CREATE TABLE important_data (value TEXT)');
    unknown.close();
    await expectLater(
      prepareUpgradeSnapshot(file, stopRunning: () async {}),
      throwsStateError,
    );
  });

  test(
    'upgrade snapshot includes committed WAL and precedes schema writes',
    () async {
      final file = await _legacyDatabase(2);
      final writer = sqlite.sqlite3.open(file.path);
      addTearDown(writer.close);
      writer.execute('PRAGMA journal_mode = WAL');
      writer.execute('PRAGMA wal_autocheckpoint = 0');
      writer.execute(
        "UPDATE core_config SET name = 'WAL-only name' WHERE id = 11",
      );
      var stopped = false;
      final snapshot = await prepareUpgradeSnapshot(
        file,
        stopRunning: () async {
          stopped = true;
        },
      );
      expect(stopped, isTrue);
      expect(snapshot, isNotNull);
      expect(snapshot!.path, contains('.pre-v3-'));
      final saved = sqlite.sqlite3.open(snapshot.path);
      try {
        expect(saved.userVersion, 2);
        expect(
          saved
              .select('SELECT name FROM core_config WHERE id = 11')
              .single['name'],
          'WAL-only name',
        );
        expect(
          _snapshot(saved, hasAgeKeys: true),
          _snapshot(writer, hasAgeKeys: true),
        );
      } finally {
        saved.close();
      }
      expect(writer.userVersion, 2);
    },
  );

  test(
    'failure to stop aborts snapshot and leaves the original database intact',
    () async {
      final file = await _legacyDatabase(1);
      final before = _snapshotFile(file, hasAgeKeys: false);
      await expectLater(
        prepareUpgradeSnapshot(
          file,
          stopRunning: () async => throw StateError('Stop failed'),
        ),
        throwsStateError,
      );
      expect(_snapshotFile(file, hasAgeKeys: false), before);
      expect(
        file.parent.listSync().where(
          (entry) => entry.path.contains('.pre-v3-'),
        ),
        isEmpty,
      );
    },
  );

  test('new installation creates schema 3 with empty assets and default connection configuration', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    expect(await database.coreConfigDao.allRawRowsWithData, isEmpty);
    expect(await database.routingProfileDao.allRows, isEmpty);
    expect(await database.subscriptionDao.allRows, isEmpty);
    expect((await database.connectionConfigDao.read()).configurationJson, '{}');
    final routingTables = await database.customSelect('''
        SELECT name FROM sqlite_master
        WHERE type = 'table' AND name IN ('routing_profile', 'custom_routing_profiles')
      ''').get();
    expect(routingTables.map((row) => row.read<String>('name')), [
      'routing_profile',
    ]);
    for (final entry in {
      'core_config': ['location_source', 'last_measured_at'],
      'subscription': ['parse_failure_count', 'auto_update'],
      'geo_data': ['generation'],
      'connection_config': ['revision'],
    }.entries) {
      final columns = await database
          .customSelect('PRAGMA table_info(${entry.key})')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        isNot(anyElement(isIn(entry.value))),
      );
    }
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      3,
    );
  });

  for (final version in [1, 2]) {
    test(
      'schema $version upgrades in place without rewriting assets',
      () async {
        final file = await _legacyDatabase(version);
        final before = _snapshotFile(file, hasAgeKeys: version == 2);

        final database = AppDatabase.forTesting(NativeDatabase(file));
        try {
          final subscriptions = await database.subscriptionDao.allRows;
          expect(subscriptions.single.id, 7);
          final subscriptionColumns = await database
              .customSelect('PRAGMA table_info(subscription)')
              .get();
          expect(
            subscriptionColumns.map((row) => row.read<String>('name')),
            isNot(contains('auto_update')),
          );
          final geoDataColumns = await database
              .customSelect('PRAGMA table_info(geo_data)')
              .get();
          expect(
            geoDataColumns.map((row) => row.read<String>('name')),
            isNot(contains('generation')),
          );
          expect(
            subscriptions.single.ageSecretKey,
            version == 2 ? 'AGE-SECRET-KEY-TEST' : null,
          );
          expect(
            subscriptions.single.agePublicKey,
            version == 2 ? 'age1test' : null,
          );
          final rawRows = await database.coreConfigDao.allRawRowsWithData;
          expect(rawRows, hasLength(4));
          expect(rawRows.every((row) => !row.favorite), isTrue);
          expect(rawRows.every((row) => row.countryCode == null), isTrue);
          expect(await database.routingProfileDao.allRows, isEmpty);
          expect(
            (await database.connectionConfigDao.read()).configurationJson,
            '{}',
          );
          final routingTables = await database.customSelect('''
            SELECT name FROM sqlite_master
            WHERE type = 'table' AND name IN ('routing_profile', 'custom_routing_profiles')
          ''').get();
          expect(routingTables.map((row) => row.read<String>('name')), [
            'routing_profile',
          ]);
        } finally {
          await database.close();
        }

        expect(_snapshotFile(file, hasAgeKeys: true), _afterUpgrade(before));
        expect(
          await prepareUpgradeSnapshot(
            file,
            stopRunning: () async => fail('Current schema must not stop VPN'),
          ),
          isNull,
        );
        final reopened = AppDatabase.forTesting(NativeDatabase(file));
        try {
          expect(await reopened.coreConfigDao.allRawRowsWithData, hasLength(4));
          expect(
            (await reopened.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            3,
          );
        } finally {
          await reopened.close();
        }
        expect(_snapshotFile(file, hasAgeKeys: true), _afterUpgrade(before));
      },
    );

    test(
      'schema $version DDL failure rolls back and a new connection retries',
      () async {
        final file = await _legacyDatabase(version);
        final before = _snapshotFile(file, hasAgeKeys: version == 2);
        final conflicting = sqlite.sqlite3.open(file.path);
        conflicting.execute(
          'CREATE INDEX connection_config ON core_config(name)',
        );
        conflicting.close();

        final failed = AppDatabase.forTesting(NativeDatabase(file));
        await expectLater(failed.subscriptionDao.allRows, throwsA(anything));
        await failed.close();

        final check = sqlite.sqlite3.open(file.path);
        try {
          expect(check.userVersion, version);
          expect(
            _columnNames(check, 'core_config'),
            isNot(contains('favorite')),
          );
          if (version == 1) {
            expect(
              _columnNames(check, 'subscription'),
              isNot(contains('age_secret_key')),
            );
          }
          expect(_snapshot(check, hasAgeKeys: version == 2), before);
          expect(
            check.select(
              "SELECT name FROM sqlite_master WHERE name = 'routing_profile'",
            ),
            isEmpty,
          );
          check.execute('DROP INDEX connection_config');
        } finally {
          check.close();
        }

        final retried = AppDatabase.forTesting(NativeDatabase(file));
        try {
          expect(await retried.subscriptionDao.allRows, hasLength(1));
          expect(await retried.routingProfileDao.allRows, isEmpty);
          expect(
            (await retried.connectionConfigDao.read()).configurationJson,
            '{}',
          );
        } finally {
          await retried.close();
        }
        expect(_snapshotFile(file, hasAgeKeys: true), _afterUpgrade(before));
      },
    );
  }

  test('version commits with DDL before a later open callback fails', () async {
    final file = await _legacyDatabase(2);
    final before = _snapshotFile(file, hasAgeKeys: true);
    final interrupted = _InterruptedAfterUpgrade(NativeDatabase(file));
    await expectLater(interrupted.subscriptionDao.allRows, throwsStateError);
    await interrupted.close();

    final check = sqlite.sqlite3.open(file.path);
    expect(check.userVersion, 3);
    expect(_columnNames(check, 'core_config'), contains('favorite'));
    expect(_columnNames(check, 'connection_config'), [
      'id',
      'configuration_json',
    ]);
    check.close();

    final retried = AppDatabase.forTesting(NativeDatabase(file));
    try {
      expect(await retried.coreConfigDao.allRawRowsWithData, hasLength(4));
    } finally {
      await retried.close();
    }
    expect(_snapshotFile(file, hasAgeKeys: true), _afterUpgrade(before));
  });

  test(
    'missing subscription cache and GeoData do not block upgrading',
    () async {
      final file = await _legacyDatabase(2);
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.execute('DELETE FROM core_config WHERE sub_id <> 0');
      legacy.execute('DELETE FROM geo_data');
      legacy.close();
      final before = _snapshotFile(file, hasAgeKeys: true);

      final database = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(await database.subscriptionDao.allRows, hasLength(1));
        expect(await database.geoDataDao.allRows, isEmpty);
      } finally {
        await database.close();
      }
      expect(_snapshotFile(file, hasAgeKeys: true), _afterUpgrade(before));
    },
  );

  test(
    'development schema is rejected without changing the original database',
    () async {
      final file = await _legacyDatabase(2);
      final legacy = sqlite.sqlite3.open(file.path);
      legacy.userVersion = 7;
      legacy.close();
      final before = _snapshotFile(file, hasAgeKeys: true);
      await expectLater(
        prepareUpgradeSnapshot(
          file,
          stopRunning: () async => fail('Unsupported schema must not stop VPN'),
        ),
        throwsStateError,
      );
      final database = AppDatabase.forTesting(NativeDatabase(file));
      await expectLater(database.subscriptionDao.allRows, throwsStateError);
      await database.close();
      expect(await file.exists(), isTrue);
      final check = sqlite.sqlite3.open(file.path);
      try {
        expect(check.userVersion, 7);
        expect(_snapshot(check, hasAgeKeys: true), before);
      } finally {
        check.close();
      }
    },
  );
}

class _InterruptedAfterUpgrade extends AppDatabase {
  _InterruptedAfterUpgrade(super.executor) : super.forTesting();

  @override
  MigrationStrategy get migration {
    final original = super.migration;
    return MigrationStrategy(
      onCreate: original.onCreate,
      onUpgrade: original.onUpgrade,
      beforeOpen: (_) async =>
          throw StateError('Interrupted after schema commit'),
    );
  }
}

Future<File> _legacyDatabase(int version) async {
  final directory = await _fixtureDirectory('onexray-schema-test-');
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}/db.sqlite');
  final database = sqlite.sqlite3.open(file.path);
  try {
    database.execute('''
      CREATE TABLE core_config (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, type TEXT NOT NULL, tags TEXT NOT NULL,
        data TEXT, delay INTEGER NOT NULL, sub_id INTEGER NOT NULL
      )
    ''');
    database.execute('''
      CREATE TABLE subscription (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, url TEXT NOT NULL, timestamp INTEGER NOT NULL,
        count INTEGER NOT NULL,
        expanded INTEGER NOT NULL CHECK (expanded IN (0, 1))
      )
    ''');
    database.execute('''
      CREATE TABLE geo_data (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, type TEXT NOT NULL, url TEXT NOT NULL,
        timestamp INTEGER NOT NULL, category_count INTEGER NOT NULL,
        rule_count INTEGER NOT NULL
      )
    ''');
    database.execute('''
      INSERT INTO subscription (id, name, url, timestamp, count, expanded)
      VALUES (7, 'Existing', 'https://example.com/sub', 123, 1, 1)
    ''');
    if (version >= 2) {
      database.execute(
        'ALTER TABLE subscription ADD COLUMN age_secret_key TEXT',
      );
      database.execute(
        'ALTER TABLE subscription ADD COLUMN age_public_key TEXT',
      );
      database.execute('''
        UPDATE subscription SET
          age_secret_key = 'AGE-SECRET-KEY-TEST', age_public_key = 'age1test'
      ''');
    }
    final entries = [
      [11, 'outbound', 0, base64Encode(utf8.encode('{"tag":"本地😀"}'))],
      [12, 'outbound', 7, 'not base64!'],
      [13, 'outbound', 0, null],
      [14, 'outbound', 0, base64Encode(utf8.encode('not JSON'))],
      for (var id = 21; id <= 24; id++)
        [id, 'raw', 0, base64Encode(utf8.encode('{"legacy":$id}'))],
      [31, 'setting', 0, 'retired profile data'],
      [32, 'full', 0, 'retired multi-node data'],
      [33, 'unknown-type', 0, 'future data'],
    ];
    for (final entry in entries) {
      database.execute(
        '''
        INSERT INTO core_config (id, name, type, tags, data, delay, sub_id)
        VALUES (?, ?, ?, 'legacy-tags', ?, 123, ?)
      ''',
        [entry[0], 'Config ${entry[0]}', entry[1], entry[3], entry[2]],
      );
    }
    database.execute('''
      INSERT INTO geo_data
        (id, name, type, url, timestamp, category_count, rule_count)
      VALUES (5, 'legacy-geosite', 'domain', 'https://example.com/geo', 123, 2, 3)
    ''');
    database.execute('PRAGMA user_version = $version');
  } finally {
    database.close();
  }
  return file;
}

Future<Directory> _fixtureDirectory(String prefix) async {
  final fixtures = await Directory(
    '../references/onexray-refactor-validation/test-fixtures',
  ).absolute.create(recursive: true);
  return fixtures.createTemp(prefix);
}

Map<String, List<List<Object?>>> _snapshotFile(
  File file, {
  required bool hasAgeKeys,
}) {
  final database = sqlite.sqlite3.open(file.path);
  try {
    return _snapshot(database, hasAgeKeys: hasAgeKeys);
  } finally {
    database.close();
  }
}

Map<String, List<List<Object?>>> _snapshot(
  sqlite.Database database, {
  required bool hasAgeKeys,
}) {
  final columns = {
    'core_config': 'id, name, type, tags, data, delay, sub_id',
    'subscription':
        'id, name, url, timestamp, count, expanded, '
        '${hasAgeKeys ? 'age_secret_key, age_public_key' : 'NULL, NULL'}',
    'geo_data': 'id, name, type, url, timestamp, category_count, rule_count',
  };
  return {
    for (final entry in columns.entries)
      entry.key: database
          .select('SELECT ${entry.value} FROM ${entry.key} ORDER BY id')
          .map((row) => row.values.toList())
          .toList(),
  };
}

List<String> _columnNames(sqlite.Database database, String table) => database
    .select('PRAGMA table_info($table)')
    .map((row) => row['name'] as String)
    .toList();

Map<String, List<List<Object?>>> _afterUpgrade(
  Map<String, List<List<Object?>>> before,
) => {
  ...before,
  'core_config': [
    for (final row in before['core_config']!)
      [
        for (var index = 0; index < row.length; index++)
          if (row[2] == 'outbound' && index == 5)
            PingDelayConstants.unknown
          else
            row[index],
      ],
  ],
};
