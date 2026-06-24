import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/metrics/service.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';
import 'package:path_provider/path_provider.dart';

final class AppDataCleanupService {
  static final AppDataCleanupService _singleton =
      AppDataCleanupService._internal();

  factory AppDataCleanupService() => _singleton;

  AppDataCleanupService._internal();

  Future<bool> clearFromSettings() async {
    return _clear(
      targetXraySettingId: XraySettingSimple.simpleId,
      clearUserDataPreferences: true,
      clearCache: true,
    );
  }

  Future<bool> clearForBackupRestore() async {
    return _clear(
      targetXraySettingId: DBConstants.defaultId,
      clearUserDataPreferences: false,
      clearCache: false,
    );
  }

  Future<bool> _clear({
    required int targetXraySettingId,
    required bool clearUserDataPreferences,
    required bool clearCache,
  }) async {
    try {
      if (!await _stopVpnIfNeeded()) {
        return false;
      }
      await _clearPreferences(
        targetXraySettingId: targetXraySettingId,
        clearUserDataPreferences: clearUserDataPreferences,
      );
      await _clearDatabase();
      await _clearRuntimeFiles();
      await _resetDatDir();
      if (clearCache) {
        await _clearCache();
      }
      _resetRuntimeState(targetXraySettingId);
      return true;
    } catch (e, stackTrace) {
      ygLogger("clear app data error: $e\n$stackTrace");
      return false;
    }
  }

  Future<bool> _stopVpnIfNeeded() async {
    final state = AppEventBus.instance.state;
    final idle =
        state.runningId == DBConstants.defaultId &&
        state.pendingConfigId == DBConstants.defaultId &&
        state.vpnActionState == VpnActionState.idle;
    if (idle) {
      return true;
    }

    final result = await VpnService().stopDefaultVpn();
    return result.state == NativeVpnCommandState.success;
  }

  Future<void> _clearPreferences({
    required int targetXraySettingId,
    required bool clearUserDataPreferences,
  }) async {
    final preferences = PreferencesKey();
    if (clearUserDataPreferences) {
      await preferences.clearUserDataPreferences();
    }
    await preferences.saveRunningConfigId(DBConstants.defaultId);
    await preferences.saveLastConfigId(DBConstants.defaultId);
    await preferences.saveXraySettingId(targetXraySettingId);
  }

  Future<void> _clearDatabase() async {
    final db = AppDatabase();
    await db.geoDataDao.clear();
    await db.coreConfigDao.clear();
    await db.subscriptionDao.clear();
  }

  Future<void> _clearRuntimeFiles() async {
    await FileTool.deleteDirIfExists(VpnConstants.runDir);
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

  void _resetRuntimeState(int targetXraySettingId) {
    XrayMetricsService().stop();
    final eventBus = AppEventBus.instance;
    eventBus.updateRunningId(DBConstants.defaultId);
    eventBus.updatePendingConfigId(DBConstants.defaultId);
    eventBus.updateXraySettingId(targetXraySettingId);
    eventBus.updateVpnActionState(VpnActionState.idle);
    eventBus.updateVpnErrorMessage("");
    eventBus.resetConnectivityProbe();
    eventBus.resetTrafficMetrics();
  }
}
