import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/service/app_startup/service.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/metrics/service.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:path_provider/path_provider.dart';

final class AppDataCleanupService {
  static final AppDataCleanupService _singleton =
      AppDataCleanupService._internal();

  factory AppDataCleanupService() => _singleton;

  AppDataCleanupService._internal();

  Future<bool> clearFromSettings() async {
    return _clear(
      targetXrayProfileId: XrayProfileSimple.simpleId,
      clearUserDataPreferences: true,
      clearCache: true,
    );
  }

  Future<bool> prepareForBackupRestore() async {
    try {
      if (!await _stopVpnIfNeeded()) {
        return false;
      }
      await _clearRuntimeFiles();
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
