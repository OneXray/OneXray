import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';

class ConfigWriteResult {
  final int count;
  final List<int> ids;

  const ConfigWriteResult({required this.count, required this.ids});
}

class ConfigWriter {
  // Inputs are already encoded by their format-specific readers. This shared
  // asset writer owns type/count transactions, never a second base64 pass.
  static Future<ConfigWriteResult> writeRowsInTransaction(
    AppDatabase db,
    List<CoreConfigCompanion> rows,
    int? subId,
  ) => DataMaintenance.run(
    () => db.transaction(() async {
      var count = 0;
      final ids = <int>[];
      for (var row in rows) {
        if (subId != null) {
          row = row.copyWith(subId: Value<int>(subId));
        }
        final res = await db.coreConfigDao.insertAssetRow(row);
        if (res <= DBConstants.defaultId) {
          throw StateError('insert core config failed');
        }
        count += 1;
        ids.add(res);
      }
      return ConfigWriteResult(count: count, ids: ids);
    }),
  );

  static Future<int> writeRowsBatchInTransaction(
    AppDatabase db,
    List<CoreConfigCompanion> rows,
    int subId,
  ) async {
    final entries = rows
        .map((row) => row.copyWith(subId: Value<int>(subId)))
        .toList(growable: false);
    return DataMaintenance.run(() => db.coreConfigDao.insertAssetRows(entries));
  }
}
