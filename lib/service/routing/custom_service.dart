import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/routing/state.dart';
import 'package:onexray/service/routing/state_db.dart';

/// Persists validated Custom-routing state. Applying a currently used profile
/// remains the connection coordinator's responsibility.
class CustomRoutingService {
  final AppDatabase database;

  CustomRoutingService(this.database);

  static RoutingProfileState read(RoutingProfileData row) =>
      RoutingProfileStateDb.read(row);

  Future<int> save(RoutingProfileState state) => DataMaintenance.run(() async {
    final name = state.name.trim();
    if (name.isEmpty || name.runes.length > 32) {
      throw const FormatException(
        'Custom route name must contain 1–32 characters',
      );
    }
    final value = state.copyWith(name: name);
    value.validate();
    return database.transaction(() async {
      if ((await database.routingProfileDao.allRows).any(
        (row) =>
            row.id != value.id &&
            row.name.trim().toLowerCase() == name.toLowerCase(),
      )) {
        throw const FormatException('Custom route names must be unique');
      }
      if (value.id == null) {
        return database.routingProfileDao.insertRow(value.insertCompanion);
      }
      final previous = await database.routingProfileDao.searchRow(value.id!);
      if (previous == null) throw StateError('Custom route no longer exists');
      await database.routingProfileDao.updateRow(value.updateData(previous));
      return value.id!;
    });
  });
}
