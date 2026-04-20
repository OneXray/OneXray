import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';

class ConfigWriter {
  static Future<int> writeRows(
    List<CoreConfigCompanion> rows,
    int? subId,
  ) async {
    var count = 0;
    final db = AppDatabase();
    for (var row in rows) {
      if (subId != null) {
        row = row.copyWith(subId: Value<int>(subId));
      }
      final res = await db.coreConfigDao.insertRow(row);
      if (res > DBConstants.defaultId) {
        count += 1;
      }
    }
    return count;
  }
}
