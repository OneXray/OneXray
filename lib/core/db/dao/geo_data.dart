import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/table/geo_data.dart';
import 'package:onexray/service/geo_data/enum.dart';
import 'package:drift/drift.dart';

part 'geo_data.g.dart';

@DriftAccessor(tables: [GeoData])
class GeoDataDao extends DatabaseAccessor<AppDatabase> with _$GeoDataDaoMixin {
  GeoDataDao(super.db);

  Stream<List<GeoDataData>> get allRowsStream => select(geoData).watch();

  Future<List<GeoDataData>> get allRows async => select(geoData).get();

  Stream<List<GeoDataData>> get allDomainRowsStream => (select(geoData)
        ..where((tbl) => tbl.type.equals(GeoDataType.domain.name)))
      .watch();

  Stream<List<GeoDataData>> get allIpRowsStream =>
      (select(geoData)..where((tbl) => tbl.type.equals(GeoDataType.ip.name)))
          .watch();

  Future<GeoDataData?> searchRow(int id) async {
    return (select(geoData)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<GeoDataData?> searchRowByName(String name) async {
    return (select(geoData)..where((tbl) => tbl.name.equals(name)))
        .getSingleOrNull();
  }

  Future<bool> nameExists(String name) async {
    final res = await (select(geoData)..where((tbl) => tbl.name.equals(name)))
        .getSingleOrNull();
    return res != null;
  }

  Future<bool> updateRow(GeoDataData entry) async {
    return update(geoData).replace(entry);
  }

  Future<int> insertRow(GeoDataCompanion entry) async {
    return into(geoData).insert(entry);
  }

  Future<int> deleteRow(int id) async {
    final res = await (delete(geoData)..where((tbl) => tbl.id.equals(id))).go();
    return res;
  }

  Future<int> clear() async {
    final res = await delete(geoData).go();
    return res;
  }
}
