// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'geo_data.dart';

// ignore_for_file: type=lint
mixin _$GeoDataDaoMixin on DatabaseAccessor<AppDatabase> {
  $GeoDataTable get geoData => attachedDatabase.geoData;
  GeoDataDaoManager get managers => GeoDataDaoManager(this);
}

class GeoDataDaoManager {
  final _$GeoDataDaoMixin _db;
  GeoDataDaoManager(this._db);
  $$GeoDataTableTableManager get geoData =>
      $$GeoDataTableTableManager(_db.attachedDatabase, _db.geoData);
}
