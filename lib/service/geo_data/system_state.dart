import 'dart:io';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/geo_data/enum.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:path/path.dart' as p;

enum SystemGeoDatId {
  geoSite(-2),
  geoIp(-1);

  const SystemGeoDatId(this.id);

  final int id;

  @override
  String toString() => "$id";
}

enum SystemGeoDatName {
  geoSite("geosite"),
  geoIp("geoip");

  const SystemGeoDatName(this.name);

  final String name;

  @override
  String toString() => name;
}

enum SystemGeoDatURL {
  geoSite(
    "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat",
  ),
  geoIp("https://github.com/v2fly/geoip/releases/latest/download/geoip.dat");

  const SystemGeoDatURL(this.name);

  final String name;

  @override
  String toString() => name;
}

class SystemGeoDatState {
  static Future<List<GeoDataData>> get system async {
    final system = <GeoDataData>[];
    final timestamp = await _timestamp;
    final geoSite = await _geoSite(timestamp);
    system.add(geoSite);
    final geoIp = await _geoIp(timestamp);
    system.add(geoIp);
    return system;
  }

  static Future<List<GeoDataData>> get geoSite async {
    final system = <GeoDataData>[];
    final timestamp = await _timestamp;
    final geoSite = await _geoSite(timestamp);
    system.add(geoSite);
    return system;
  }

  static Future<List<GeoDataData>> get geoIp async {
    final system = <GeoDataData>[];
    final timestamp = await _timestamp;
    final geoIp = await _geoIp(timestamp);
    system.add(geoIp);
    return system;
  }

  static Future<GeoDataData> _geoSite(DateTime timestamp) async {
    final geoList = await GeoDataService().readGeoList(
      VpnConstants.datDir,
      SystemGeoDatName.geoSite.name,
    );
    var categoryCount = 0;
    if (geoList.categoryCount != null) {
      categoryCount = geoList.categoryCount!;
    }
    var ruleCount = 0;
    if (geoList.ruleCount != null) {
      ruleCount = geoList.ruleCount!;
    }
    final geoSite = GeoDataData(
      id: SystemGeoDatId.geoSite.id,
      name: SystemGeoDatName.geoSite.name,
      type: GeoDataType.domain.name,
      url: SystemGeoDatURL.geoSite.name,
      timestamp: timestamp,
      categoryCount: categoryCount,
      ruleCount: ruleCount,
    );
    return geoSite;
  }

  static Future<GeoDataData> _geoIp(DateTime timestamp) async {
    final geoList = await GeoDataService().readGeoList(
      VpnConstants.datDir,
      SystemGeoDatName.geoIp.name,
    );
    var categoryCount = 0;
    if (geoList.categoryCount != null) {
      categoryCount = geoList.categoryCount!;
    }
    var ruleCount = 0;
    if (geoList.ruleCount != null) {
      ruleCount = geoList.ruleCount!;
    }
    final geoIp = GeoDataData(
      id: SystemGeoDatId.geoIp.id,
      name: SystemGeoDatName.geoIp.name,
      type: GeoDataType.ip.name,
      url: SystemGeoDatURL.geoIp.name,
      timestamp: timestamp,
      categoryCount: categoryCount,
      ruleCount: ruleCount,
    );
    return geoIp;
  }

  static Future<DateTime> get _timestamp async {
    final datPath = VpnConstants.datDir;
    final timestampPath = p.join(datPath, "timestamp.txt");
    final timestampFile = File(timestampPath);
    final exists = await timestampFile.exists();
    if (exists) {
      var timestamp = await timestampFile.readAsString();
      timestamp = timestamp.trim();
      final timestampInt = int.tryParse(timestamp);
      if (timestampInt != null) {
        final timestampMs = timestampInt * 1000;
        final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
        return dt;
      }
    }
    return DateTime.now();
  }
}
