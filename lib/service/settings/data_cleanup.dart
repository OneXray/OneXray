import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/launch/app_startup.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/advanced/xray/data_update/service.dart';
import 'package:onexray/service/servers/import.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/shared/ping/service.dart';
import 'package:path_provider/path_provider.dart';

final class AppDataCleanupService {
  static final AppDataCleanupService _singleton = AppDataCleanupService._(
    ConnectionCoordinator.instance,
    GeoDataService(),
    SubscriptionService(),
    PingService(),
    null,
  );

  factory AppDataCleanupService() => _singleton;

  AppDataCleanupService._(
    this._coordinator,
    this._geodata,
    this._subscriptions,
    this._ping,
    this._clearOverride,
  );

  @visibleForTesting
  factory AppDataCleanupService.forTesting({
    required ConnectionCoordinator coordinator,
    required GeoDataService geodata,
    required SubscriptionService subscriptions,
    required PingService ping,
    required Future<void> Function() clear,
  }) =>
      AppDataCleanupService._(coordinator, geodata, subscriptions, ping, clear);

  final ConnectionCoordinator _coordinator;
  final GeoDataService _geodata;
  final SubscriptionService _subscriptions;
  final PingService _ping;
  final Future<void> Function()? _clearOverride;
  bool _clearing = false;

  Future<bool> clearFromSettings() async {
    if (_clearing) return false;
    _clearing = true;
    try {
      // Pause every producer before awaiting any one of them. In-flight imports
      // may finish their current write, but cannot start another source/probe.
      await Future.wait([
        DataUpdateService().pauseForDataClear(),
        ServerImportService.pauseForDataClear(),
        _subscriptions.pauseForDataClear(),
        _ping.pauseForDataClear(),
        _coordinator.pauseForDataClear(),
        _geodata.pauseForDataClear(),
      ]);
      await _geodata.withFiles(() async {
        await _coordinator.stopForMaintenance();
        await (_clearOverride ?? _clear)();
      });
      return true;
    } catch (e, stackTrace) {
      ygLogger("clear app data error: $e\n$stackTrace");
      return false;
    } finally {
      _geodata.resumeAfterDataClear();
      _coordinator.resumeAfterDataClear();
      _ping.resumeAfterDataClear();
      _subscriptions.resumeAfterDataClear();
      ServerImportService.resumeAfterDataClear();
      DataUpdateService().resumeAfterDataClear();
      _clearing = false;
    }
  }

  Future<void> _clear() async {
    await AppStartupService().unregisterForDataCleanup();
    await PreferencesKey().clearUserDataPreferences();
    await NetClient().updateUserAgentMode(DownloadUserAgentMode.defaultMode);
    await _clearDatabase();
    await _clearRuntimeFiles();
    _coordinator.clearTrafficView();
    await _geodata.resetAfterDataClear();
    await _clearCache();
  }

  Future<void> _clearDatabase() async {
    final db = AppDatabase();
    await db.transaction(() async {
      await db.geoDataDao.clear();
      await db.coreConfigDao.clear();
      await db.subscriptionDao.clear();
      await db.routingProfileDao.clear();
      await db.connectionConfigDao.reset();
    });
  }

  Future<void> _clearRuntimeFiles() async {
    final directory = Directory(VpnConstants.runDir);
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      await entry.delete(recursive: true);
    }
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
