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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await customStatement('PRAGMA user_version = $schemaVersion');
    }),
    onUpgrade: (migrator, from, to) => transaction(() async {
      // ponytail: reset incompatible development databases manually; add a new
      // migration only for a later released App version, not this development cycle.
      if ((from != 1 && from != 2) || to != 3) {
        throw StateError('Unsupported database schema upgrade');
      }

      if (from == 1) {
        await migrator.addColumn(subscription, subscription.ageSecretKey);
        await migrator.addColumn(subscription, subscription.agePublicKey);
      }
      await migrator.addColumn(coreConfig, coreConfig.countryCode);
      await migrator.addColumn(coreConfig, coreConfig.locationSource);
      await migrator.addColumn(coreConfig, coreConfig.lastMeasuredAt);
      await migrator.addColumn(coreConfig, coreConfig.favorite);
      await migrator.addColumn(subscription, subscription.parseFailureCount);
      await migrator.addColumn(subscription, subscription.autoUpdate);
      await migrator.addColumn(geoData, geoData.generation);
      await migrator.createTable(customRoutingProfiles);
      await migrator.createTable(connectionState);

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
