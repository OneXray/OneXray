import 'dart:io';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/service/app_startup/service.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class AppDataCleanupService {
  static final AppDataCleanupService _singleton =
      AppDataCleanupService._internal();

  factory AppDataCleanupService() => _singleton;

  AppDataCleanupService._internal();

  Future<bool> clearFromSettings() => DataMaintenance.exclusive(_clear);

  Future<bool> prepareForBackupRestore() async {
    try {
      await ConnectionCoordinator.instance.stopForMaintenance();
      await _clearRuntimeFiles(preserveTraffic: true);
      return true;
    } catch (e, stackTrace) {
      ygLogger("prepare backup restore error: $e\n$stackTrace");
      return false;
    }
  }

  Future<bool> _clear() async {
    try {
      await ConnectionCoordinator.instance.stopForMaintenance();
      await AppStartupService().unregisterForDataCleanup();
      await PreferencesKey().clearUserDataPreferences();
      await NetClient().updateUserAgentMode(DownloadUserAgentMode.defaultMode);
      await _clearDatabase();
      await _clearRuntimeFiles();
      ConnectionCoordinator.instance.clearTrafficView();
      await _resetDatDir();
      await _clearCache();
      return true;
    } catch (e, stackTrace) {
      ygLogger("clear app data error: $e\n$stackTrace");
      return false;
    }
  }

  Future<void> _clearDatabase() async {
    final db = AppDatabase();
    await db.transaction(() async {
      await db.geoDataDao.clear();
      await db.coreConfigDao.clear();
      await db.subscriptionDao.clear();
      await db.routingProfileDao.clear();
      await db.connectionStateDao.reset();
    });
  }

  Future<void> _clearRuntimeFiles({bool preserveTraffic = false}) async {
    final directory = Directory(VpnConstants.runDir);
    if (!await directory.exists()) return;
    const retained = {
      'runtime.json',
      'runtime.json.lock',
      'traffic-totals.json',
    };
    await for (final entry in directory.list(followLinks: false)) {
      if (preserveTraffic && retained.contains(p.basename(entry.path))) {
        continue;
      }
      await entry.delete(recursive: true);
    }
  }

  Future<void> _resetDatDir() async {
    final datPath = VpnConstants.datDir;
    await FileTool.deleteDirIfExists(datPath);
    await FileTool.checkDir(datPath);
    await FileTool.copyAssets(Assets.dat.values, datPath);
  }

  Future<void> _clearCache() async {
    final cacheDir = await getApplicationCacheDirectory();
    if (!await cacheDir.exists()) {
      return;
    }
    await for (final entity in cacheDir.list()) {
      try {
        await entity.delete(recursive: true);
      } catch (e) {
        ygLogger("delete cache failed: ${entity.path}, $e");
      }
    }
  }
}
