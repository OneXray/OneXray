import 'dart:io';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/service/app_startup/service.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/xray/metrics/service.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class AppDataCleanupService {
  static final AppDataCleanupService _singleton =
      AppDataCleanupService._internal();

  factory AppDataCleanupService() => _singleton;

  AppDataCleanupService._internal();

  Future<bool> clearFromSettings() => DataMaintenance.exclusive(
    () => _clear(
      targetXrayProfileId: XrayProfileSimple.simpleId,
      clearUserDataPreferences: true,
      clearCache: true,
    ),
  );

  Future<bool> prepareForBackupRestore() async {
    try {
      if (!await _stopVpnIfNeeded()) {
        return false;
      }
      await _clearRuntimeFiles(preserveTraffic: true);
      return true;
    } catch (e, stackTrace) {
      ygLogger("prepare backup restore error: $e\n$stackTrace");
      return false;
    }
  }

  Future<void> finishBackupRestore() async {
    try {
      await _clearPreferences(
        targetXrayProfileId: XrayProfileSimple.simpleId,
        clearUserDataPreferences: false,
      );
    } catch (e, stackTrace) {
      ygLogger("finish backup restore preferences error: $e\n$stackTrace");
    } finally {
      _resetRuntimeState(XrayProfileSimple.simpleId);
    }
  }

  Future<bool> _clear({
    required int targetXrayProfileId,
    required bool clearUserDataPreferences,
    required bool clearCache,
  }) async {
    try {
      if (!await _stopVpnIfNeeded()) {
        return false;
      }
      if (clearUserDataPreferences) {
        await AppStartupService().unregisterForDataCleanup();
      }
      await _clearPreferences(
        targetXrayProfileId: targetXrayProfileId,
        clearUserDataPreferences: clearUserDataPreferences,
      );
      if (clearUserDataPreferences) {
        await NetClient().updateUserAgentMode(
          DownloadUserAgentMode.defaultMode,
        );
      }
      await _clearDatabase();
      await _clearRuntimeFiles();
      ConnectionCoordinator.instance.clearTrafficView();
      await _resetDatDir();
      if (clearCache) {
        await _clearCache();
      }
      _resetRuntimeState(targetXrayProfileId);
      return true;
    } catch (e, stackTrace) {
      ygLogger("clear app data error: $e\n$stackTrace");
      return false;
    }
  }

  Future<bool> _stopVpnIfNeeded() async {
    await ConnectionCoordinator.instance.stopForMaintenance();
    return true;
  }

  Future<void> _clearPreferences({
    required int targetXrayProfileId,
    required bool clearUserDataPreferences,
  }) async {
    final preferences = PreferencesKey();
    if (clearUserDataPreferences) {
      await preferences.clearUserDataPreferences();
    }
    await preferences.saveRunningConfigId(DBConstants.defaultId);
    await preferences.saveLastConfigId(DBConstants.defaultId);
    await preferences.saveXrayProfileId(targetXrayProfileId);
  }

  Future<void> _clearDatabase() async {
    final db = AppDatabase();
    await db.transaction(() async {
      await db.geoDataDao.clear();
      await db.coreConfigDao.clear();
      await db.subscriptionDao.clear();
      await db.customRoutingProfilesDao.clear();
      await db.connectionStateDao.reset();
    });
  }

  Future<void> _clearRuntimeFiles({bool preserveTraffic = false}) async {
    final directory = Directory(VpnConstants.runDir);
    if (!await directory.exists()) return;
    const retained = {
      'runtime.json',
      'runtime.json.lock',
      'runtime-sessions',
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

  void _resetRuntimeState(int targetXrayProfileId) {
    XrayMetricsService().stop();
    final eventBus = AppEventBus.instance;
    eventBus.updateRunningId(DBConstants.defaultId);
    eventBus.updatePendingConfigId(DBConstants.defaultId);
    eventBus.updateXrayProfileId(targetXrayProfileId);
    eventBus.updateVpnActionState(VpnActionState.idle);
    eventBus.updateVpnErrorMessage("");
    eventBus.resetConnectivityProbe();
    eventBus.resetTrafficMetrics();
  }
}
