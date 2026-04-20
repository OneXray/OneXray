import 'dart:async';
import 'dart:io';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/geo_data/enum.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:path/path.dart' as p;

class GeoDataService {
  static final GeoDataService _singleton = GeoDataService._internal();

  factory GeoDataService() => _singleton;

  GeoDataService._internal();

  Future<XrayGeoList> readGeoList(String datDir, String name) async {
    final geoListPath = p.join(datDir, "$name.json");
    final geoListFile = File(geoListPath);
    final exists = await geoListFile.exists();
    if (exists) {
      final geoListData = await geoListFile.readAsString();
      final geoListMap = JsonTool.decoder.convert(geoListData);
      final geoList = XrayGeoList.fromJson(geoListMap);
      return geoList;
    }
    return XrayGeoList(null, null, null);
  }

  Future<bool> insertGeoDat(
    String name,
    GeoDataType type,
    String url, {
    bool showLoading = true,
    bool needDownload = true,
  }) async {
    final eventBus = AppEventBus.instance;
    if (showLoading) {
      eventBus.updateDownloading(true);
    }
    var datDir = VpnConstants.datDir;
    var res = true;
    if (needDownload) {
      datDir = await FileTool.makeCacheDir();
      res = await _downloadFile(url, name, datDir);
      if (res) {
        res = await _generateCode(datDir, name, type.name);
      }
    }

    if (res) {
      final geoList = await readGeoList(datDir, name);
      try {
        final db = AppDatabase();
        final row = GeoDataCompanion.insert(
          name: name,
          type: type.name,
          url: url,
          timestamp: DateTime.now(),
          categoryCount: geoList.categoryCount ?? 0,
          ruleCount: geoList.ruleCount ?? 0,
        );
        await db.geoDataDao.insertRow(row);
      } catch (_) {
        res = false;
      }
    }
    if (res && needDownload) {
      await FileTool.copyDir(datDir, VpnConstants.datDir);
      await FileTool.deleteDirIfExists(datDir);
    }

    if (showLoading) {
      eventBus.updateDownloading(false);
    }
    return res;
  }

  Future<bool> updateGeoDat(GeoDataData geoDat) async {
    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);

    final cacheDir = await FileTool.makeCacheDir();
    var res = await _downloadFile(geoDat.url, geoDat.name, cacheDir);
    if (res) {
      res = await _generateCode(cacheDir, geoDat.name, geoDat.type);
      if (res) {
        final geoList = await readGeoList(cacheDir, geoDat.name);
        try {
          final row = geoDat.copyWith(
            timestamp: DateTime.now(),
            categoryCount: geoList.categoryCount ?? 0,
            ruleCount: geoList.ruleCount ?? 0,
          );
          final db = AppDatabase();
          res = await db.geoDataDao.updateRow(row);
        } catch (_) {
          res = false;
        }
      }
    }
    if (res) {
      await FileTool.copyDir(cacheDir, VpnConstants.datDir);
    }
    await FileTool.deleteDirIfExists(cacheDir);

    eventBus.updateDownloading(false);

    return res;
  }

  Future<void> refreshSystemGeoDat(List<GeoDataData> systemGeo) async {
    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);
    final cacheDir = await FileTool.makeCacheDir();
    var res = false;
    for (final geoDat in systemGeo) {
      res = await _downloadFile(geoDat.url, geoDat.name, cacheDir);
      if (!res) {
        break;
      }
      res = await _generateCode(cacheDir, geoDat.name, geoDat.type);
      if (!res) {
        break;
      }
    }
    if (res) {
      final timestamp = DateTime.now().millisecondsSinceEpoch / 1000;
      final timestampStr = "${timestamp.toInt()}";
      final timestampPath = p.join(
        VpnConstants.datDir,
        VpnConstants.systemGeoTimestamp,
      );
      final timestampFile = File(timestampPath);
      await timestampFile.writeAsString(timestampStr);
      await FileTool.copyDir(cacheDir, VpnConstants.datDir);
    }
    await FileTool.deleteDirIfExists(cacheDir);
    eventBus.updateDownloading(false);
  }

  Future<bool> _downloadFile(String url, String name, String cacheDir) async {
    final filePath = p.join(cacheDir, "$name.dat");
    return NetClient().downloadFile(url, filePath);
  }

  Future<bool> _generateCode(String cacheDir, String name, String type) async {
    final request = CountGeoDataRequest(cacheDir, name, type);
    final err = await AppHostApi().countGeoData(request);
    return err.isEmpty;
  }

  Future<void> deleteGeoDat(GeoDataData geoDat) async {
    final db = AppDatabase();
    await db.geoDataDao.deleteRow(geoDat.id);

    final name = geoDat.name;
    final jsonPath = p.join(VpnConstants.datDir, "$name.json");
    await FileTool.deleteFileIfExists(jsonPath);
    final datPath = p.join(VpnConstants.datDir, "$name.dat");
    await FileTool.deleteFileIfExists(datPath);
  }
}
