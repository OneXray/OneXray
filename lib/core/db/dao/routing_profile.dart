import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/table/routing_profile.dart';

part 'routing_profile.g.dart';

@DriftAccessor(tables: [RoutingProfile])
class RoutingProfileDao extends DatabaseAccessor<AppDatabase>
    with _$RoutingProfileDaoMixin {
  RoutingProfileDao(super.db);

  static const maxProfiles = 3;

  Future<List<RoutingProfileData>> get allRows => (select(
    routingProfile,
  )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();

  Stream<List<RoutingProfileData>> get allRowsStream => (select(
    routingProfile,
  )..orderBy([(table) => OrderingTerm.asc(table.id)])).watch();

  Future<RoutingProfileData?> searchRow(int id) => (select(
    routingProfile,
  )..where((table) => table.id.equals(id))).getSingleOrNull();

  Future<int> insertRow(RoutingProfileCompanion entry) =>
      attachedDatabase.transaction(() async {
        final count = routingProfile.id.count();
        final row = await (selectOnly(
          routingProfile,
        )..addColumns([count])).getSingle();
        if (row.read(count)! >= maxProfiles) {
          throw StateError('At most three custom routing profiles are allowed');
        }
        return into(routingProfile).insert(entry);
      });

  Future<bool> updateRow(RoutingProfileData entry) =>
      update(routingProfile).replace(entry);

  Future<int> deleteRow(int id) =>
      (delete(routingProfile)..where((table) => table.id.equals(id))).go();

  Future<int> clear() => delete(routingProfile).go();
}
