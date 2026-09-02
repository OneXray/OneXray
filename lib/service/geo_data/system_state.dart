import 'package:onexray/core/db/database/database.dart';

enum SystemGeoDatId {
  geoSite(-2),
  geoIp(-1);

  const SystemGeoDatId(this.id);
  final int id;
  @override
  String toString() => '$id';
}

enum SystemGeoDatName {
  geoSite('geosite'),
  geoIp('geoip');

  const SystemGeoDatName(this.name);
  final String name;
  @override
  String toString() => name;
}

enum SystemGeoDatURL {
  geoSite(
    'https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat',
  ),
  geoIp('https://github.com/v2fly/geoip/releases/latest/download/geoip.dat');

  const SystemGeoDatURL(this.name);
  final String name;
  @override
  String toString() => name;
}

/// Built-in timestamps/counts come from the same committed rows as custom data.
/// Reading state does not seed files or manufacture a successful update date.
class SystemGeoDatState {
  static Future<List<GeoDataData>> get system async =>
      (await AppDatabase().geoDataDao.publishedRows)
          .where((row) => row.id < 0)
          .toList();
  static Future<List<GeoDataData>> get geoSite async => (await system)
      .where((row) => row.id == SystemGeoDatId.geoSite.id)
      .toList();
  static Future<List<GeoDataData>> get geoIp async =>
      (await system).where((row) => row.id == SystemGeoDatId.geoIp.id).toList();
}
