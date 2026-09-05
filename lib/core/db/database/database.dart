import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:onexray/core/db/dao/connection_config.dart';
import 'package:onexray/core/db/dao/core_config.dart';
import 'package:onexray/core/db/dao/geo_data.dart';
import 'package:onexray/core/db/dao/routing_profile.dart';
import 'package:onexray/core/db/dao/subscription.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/table/connection_config.dart';
import 'package:onexray/core/db/table/core_config.dart';
import 'package:onexray/core/db/table/geo_data.dart';
import 'package:onexray/core/db/table/routing_profile.dart';
import 'package:onexray/core/db/table/subscription.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@DriftDatabase(
  tables: [CoreConfig, Subscription, GeoData, RoutingProfile, ConnectionConfig],
  daos: [
    CoreConfigDao,
    SubscriptionDao,
    GeoDataDao,
    RoutingProfileDao,
    ConnectionConfigDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _singleton;

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
      await migrator.addColumn(coreConfig, coreConfig.favorite);
      await migrator.createTable(routingProfile);
      await migrator.createTable(connectionConfig);

      // Old delays are not a health result for the new measurement flow.
      await (update(
        coreConfig,
      )..where((row) => row.type.equals('outbound'))).write(
        const CoreConfigCompanion(delay: Value(PingDelayConstants.unknown)),
      );

      // Drift writes this again after beforeOpen. Commit it with the DDL so an
      // interruption between those callbacks cannot leave the old version.
      await customStatement('PRAGMA user_version = $to');
    }),
  );

  static Future<Directory> _databaseDirectory() =>
      AppPlatform.isLinux || AppPlatform.isWindows
      ? getApplicationSupportDirectory()
      : getApplicationDocumentsDirectory();

  static Future<File> get databaseFile async =>
      File(p.join((await _databaseDirectory()).path, 'db.sqlite'));

  static QueryExecutor _openConnection() => driftDatabase(
    name: 'db',
    native: DriftNativeOptions(databaseDirectory: _databaseDirectory),
  );
}
