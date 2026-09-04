import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/table/geo_data.dart';
import 'package:drift/drift.dart';

part 'geo_data.g.dart';

@DriftAccessor(tables: [GeoData])
class GeoDataDao extends DatabaseAccessor<AppDatabase> with _$GeoDataDaoMixin {
  GeoDataDao(super.db);

  Future<List<GeoDataData>> get allRows async =>
      (select(geoData)..where((row) => row.id.isBiggerThanValue(0))).get();

  Stream<List<GeoDataData>> get publishedRowsStream => select(geoData).watch();

  Future<List<GeoDataData>> get publishedRows async => select(geoData).get();

  Future<GeoDataData?> searchRow(int id) async {
    return (select(
      geoData,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<GeoDataData?> searchRowByName(String name) async {
    return (select(
      geoData,
    )..where((tbl) => tbl.name.equals(name))).getSingleOrNull();
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
