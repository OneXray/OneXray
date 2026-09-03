import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:onexray/core/db/dao/connection_state.dart';
import 'package:onexray/core/db/dao/core_config.dart';
import 'package:onexray/core/db/dao/custom_routing_profiles.dart';
import 'package:onexray/core/db/dao/geo_data.dart';
import 'package:onexray/core/db/dao/subscription.dart';
import 'package:onexray/core/db/table/connection_state.dart';
import 'package:onexray/core/db/table/core_config.dart';
import 'package:onexray/core/db/table/custom_routing_profiles.dart';
import 'package:onexray/core/db/table/geo_data.dart';
import 'package:onexray/core/db/table/subscription.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@DriftDatabase(
  tables: [
    CoreConfig,
    Subscription,
    GeoData,
    CustomRoutingProfiles,
    ConnectionState,
  ],
  daos: [
    CoreConfigDao,
    SubscriptionDao,
    GeoDataDao,
    CustomRoutingProfilesDao,
    ConnectionStateDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _singleton;
  static Directory? _validationDirectory;

  /// Debug device demos use an isolated directory, including upgrade snapshots.
  /// Call before any service obtains the singleton; release builds reject this.
  @visibleForTesting
  static void useValidationDirectory(Directory directory) {
    if (!kDebugMode || _singleton != null) {
      throw StateError('Validation database must be configured before startup');
    }
    _validationDirectory = directory;
  }

  factory AppDatabase() => _singleton ??= AppDatabase._internal();

  AppDatabase._internal() : super(_openConnection());

  /// Only the exclusive startup upgrade flow may call this after an open error.
  /// The next factory call creates a fresh executor; a failed one is not reused.
  static Future<void> resetAfterOpenFailure() async {
    final failed = _singleton;
    if (failed != null) {
      try {
        await failed.close();
      } finally {
        if (identical(_singleton, failed)) {
          _singleton = null;
        }
      }
    }
  }

  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await customStatement('PRAGMA user_version = $schemaVersion');
    }),
    onUpgrade: (migrator, from, to) => transaction(() async {
      if (from < 1 || from > 6 || to != 7) {
        throw StateError('Unsupported database schema upgrade');
      }

      if (from < 3) {
        const preservedColumns = {
          'core_config': 'id, name, type, tags, data, delay, sub_id',
          'subscription':
              'id, name, url, timestamp, count, expanded, '
              'age_secret_key, age_public_key',
          'geo_data':
              'id, name, type, url, timestamp, category_count, rule_count',
        };
        // Keep comparisons inside SQLite: never load all encoded configs or
        // credentials into Dart memory, and never decode or rewrite legacy data.
        for (final entry in preservedColumns.entries) {
          final projection = entry.key == 'subscription' && from == 1
              ? 'id, name, url, timestamp, count, expanded, '
                    'NULL AS age_secret_key, NULL AS age_public_key'
              : entry.value;
          await customStatement(
            'CREATE TEMP TABLE _upgrade_v3_${entry.key} AS '
            'SELECT $projection FROM ${entry.key}',
          );
        }

        if (from < 2) {
          await migrator.addColumn(subscription, subscription.ageSecretKey);
          await migrator.addColumn(subscription, subscription.agePublicKey);
        }
        await migrator.addColumn(coreConfig, coreConfig.countryCode);
        await migrator.addColumn(coreConfig, coreConfig.locationSource);
        await migrator.addColumn(coreConfig, coreConfig.lastMeasuredAt);
        await migrator.addColumn(coreConfig, coreConfig.favorite);
        await migrator.addColumn(subscription, subscription.parseFailureCount);
        await migrator.createTable(customRoutingProfiles);

        const addedColumns = {
          'core_config': [
            'country_code',
            'location_source',
            'last_measured_at',
            'favorite',
          ],
          'subscription': [
            'age_secret_key',
            'age_public_key',
            'parse_failure_count',
          ],
          'custom_routing_profiles': ['id', 'name', 'data'],
        };
        for (final entry in addedColumns.entries) {
          final columns = await customSelect('PRAGMA table_info(${entry.key})')
              .get();
          final names = columns.map((row) => row.read<String>('name')).toSet();
          if (!names.containsAll(entry.value)) {
            throw StateError('Database schema upgrade validation failed');
          }
        }
        for (final entry in preservedColumns.entries) {
          final changedColumns = entry.value
              .split(', ')
              .map((column) => 'new_row.$column IS NOT old_row.$column')
              .join(' OR ');
          final comparison = await customSelect(
            'SELECT '
            '(SELECT COUNT(*) FROM _upgrade_v3_${entry.key}) != '
            '(SELECT COUNT(*) FROM ${entry.key}) OR EXISTS ('
            'SELECT 1 FROM _upgrade_v3_${entry.key} AS old_row '
            'LEFT JOIN ${entry.key} AS new_row ON new_row.id = old_row.id '
            'WHERE $changedColumns) AS changed',
          ).getSingle();
          if (comparison.read<int>('changed') != 0) {
            throw StateError('Database upgrade changed existing assets');
          }
          await customStatement('DROP TABLE _upgrade_v3_${entry.key}');
        }
      }

      if (from < 4) {
        await migrator.createTable(connectionState);
      } else {
        // Retire only the rollback journal and duplicated plan body. Saved
        // settings/revision and every asset table stay in the upgrade transaction.
        final rows = await customSelect(
          'SELECT id, revision, settings_json, confirmed_snapshot_json '
          'FROM connection_state',
        ).get();
        await customStatement('DROP TABLE connection_state');
        await migrator.createTable(connectionState);
        for (final row in rows) {
          String? planId;
          final text = row.data['confirmed_snapshot_json'];
          if (text is String) {
            try {
              final snapshot = jsonDecode(text);
              final id = snapshot is Map<String, dynamic>
                  ? snapshot['id']
                  : null;
              if (id is String && RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
                planId = id;
              }
            } on FormatException {
              // Discard obsolete recovery metadata, never the user's assets.
            }
          }
          await customStatement(
            'INSERT INTO connection_state '
            '(id, revision, settings_json, confirmed_plan_id) VALUES (?, ?, ?, ?)',
            [
              row.read<int>('id'),
              row.read<int>('revision'),
              row.read<String>('settings_json'),
              planId,
            ],
          );
        }
      }
      if (from < 5) {
        await migrator.addColumn(subscription, subscription.autoUpdate);
      }
      if (from < 6) await migrator.addColumn(geoData, geoData.generation);
      final geoColumns = await customSelect('PRAGMA table_info(geo_data)')
          .get();
      if (!geoColumns.any((row) => row.read<String>('name') == 'generation')) {
        throw StateError('Geodata schema upgrade validation failed');
      }
      final stateColumns = await customSelect(
        'PRAGMA table_info(connection_state)',
      ).get();
      final stateColumnNames = stateColumns
          .map((row) => row.read<String>('name'))
          .toSet();
      if (stateColumnNames.length != 4 ||
          !stateColumnNames.containsAll({
            'id',
            'revision',
            'settings_json',
            'confirmed_plan_id',
          })) {
        throw StateError('Connection state schema upgrade validation failed');
      }

      // Drift writes this again after beforeOpen. Commit it with the DDL so an
      // interruption between those callbacks cannot leave the old version.
      await customStatement('PRAGMA user_version = $to');
    }),
  );

  static Future<Directory> _databaseDirectory() => _validationDirectory != null
      ? Future.value(_validationDirectory)
      : AppPlatform.isLinux || AppPlatform.isWindows
      ? getApplicationSupportDirectory()
      : getApplicationDocumentsDirectory();

  static Future<File> get databaseFile async =>
      File(p.join((await _databaseDirectory()).path, 'db.sqlite'));

  static QueryExecutor _openConnection() => driftDatabase(
    name: 'db',
    native: DriftNativeOptions(databaseDirectory: _databaseDirectory),
  );
}
