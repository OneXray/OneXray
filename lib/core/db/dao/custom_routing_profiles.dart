import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/table/custom_routing_profiles.dart';

part 'custom_routing_profiles.g.dart';

@DriftAccessor(tables: [CustomRoutingProfiles])
class CustomRoutingProfilesDao extends DatabaseAccessor<AppDatabase>
    with _$CustomRoutingProfilesDaoMixin {
  CustomRoutingProfilesDao(super.db);

  static const maxProfiles = 3;

  Future<List<CustomRoutingProfileData>> get allRows => (select(
    customRoutingProfiles,
  )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();

  Stream<List<CustomRoutingProfileData>> get allRowsStream => (select(
    customRoutingProfiles,
  )..orderBy([(table) => OrderingTerm.asc(table.id)])).watch();

  Future<CustomRoutingProfileData?> searchRow(int id) => (select(
    customRoutingProfiles,
  )..where((table) => table.id.equals(id))).getSingleOrNull();

  Future<int> insertRow(CustomRoutingProfilesCompanion entry) =>
      attachedDatabase.transaction(() async {
        final count = customRoutingProfiles.id.count();
        final row = await (selectOnly(
          customRoutingProfiles,
        )..addColumns([count])).getSingle();
        if (row.read(count)! >= maxProfiles) {
          throw StateError('At most three custom routing profiles are allowed');
        }
        return into(customRoutingProfiles).insert(entry);
      });

  Future<bool> updateRow(CustomRoutingProfileData entry) =>
      update(customRoutingProfiles).replace(entry);

  Future<int> deleteRow(int id) => (delete(
    customRoutingProfiles,
  )..where((table) => table.id.equals(id))).go();

  Future<int> clear() => delete(customRoutingProfiles).go();
}
