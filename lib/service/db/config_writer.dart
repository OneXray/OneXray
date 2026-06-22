import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';

class ConfigWriteResult {
  final int count;
  final List<int> ids;

  const ConfigWriteResult({required this.count, required this.ids});
}

class ConfigWriter {
  static Future<int> writeRows(
    List<CoreConfigCompanion> rows,
    int? subId,
  ) async {
    final result = await writeRowsWithResult(rows, subId);
    return result.count;
  }

  static Future<ConfigWriteResult> writeRowsWithResult(
    List<CoreConfigCompanion> rows,
    int? subId,
  ) async {
    var count = 0;
    final ids = <int>[];
    final db = AppDatabase();
    for (var row in rows) {
      if (subId != null) {
        row = row.copyWith(subId: Value<int>(subId));
      }
      final res = await db.coreConfigDao.insertRow(row);
      if (res > DBConstants.defaultId) {
        count += 1;
        ids.add(res);
      }
    }
    return ConfigWriteResult(count: count, ids: ids);
  }
}
