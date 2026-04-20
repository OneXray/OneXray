import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:onexray/core/db/dao/core_config.dart';
import 'package:onexray/core/db/dao/geo_data.dart';
import 'package:onexray/core/db/dao/subscription.dart';
import 'package:onexray/core/db/table/core_config.dart';
import 'package:onexray/core/db/table/geo_data.dart';
import 'package:onexray/core/db/table/subscription.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onexray/core/tools/platform.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [CoreConfig, Subscription, GeoData],
  daos: [CoreConfigDao, SubscriptionDao, GeoDataDao],
)
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _singleton = AppDatabase._internal();

  factory AppDatabase() => _singleton;

  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    if (AppPlatform.isLinux || AppPlatform.isWindows) {
      return driftDatabase(
        name: 'db',
        native: const DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
        ),
      );
    } else {
      return driftDatabase(name: 'db');
    }
  }
}
