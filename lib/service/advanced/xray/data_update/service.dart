import 'dart:async';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/advanced/xray/geodata/system_state.dart';
import 'package:onexray/service/advanced/xray/data_update/state.dart';
import 'package:onexray/service/servers/subscription/service.dart';

class DataUpdateService {
  static final DataUpdateService _singleton = DataUpdateService._internal();

  factory DataUpdateService() => _singleton;

  DataUpdateService._internal();

  Completer<void>? _running;
  var _paused = false;

  Future<void> pauseForDataClear() {
    _paused = true;
    return _running?.future ?? Future.value();
  }

  void resumeAfterDataClear() => _paused = false;

  Future<void> checkAndRun({
    bool updateSubscription = true,
    bool updateGeoData = true,
  }) async {
    if (_paused || _running != null || AppEventBus.instance.state.downloading) {
      return;
    }

    final finished = Completer<void>();
    _running = finished;
    try {
      final autoUpdateState = AutoUpdateState();
      await autoUpdateState.readFromPreferences();
      if (_paused) return;
      final shouldUpdateSubscription =
          updateSubscription && autoUpdateState.subscriptionEnabled;
      final shouldUpdateGeoData =
          updateGeoData && autoUpdateState.geoDataEnable;
      if (!shouldUpdateSubscription && !shouldUpdateGeoData) return;
      if (shouldUpdateSubscription) {
        await SubscriptionService().refreshOutdatedSubscription(
          autoUpdateState: autoUpdateState,
          isCancelled: () => _paused,
        );
      }
      if (shouldUpdateGeoData && !_paused) {
        await _refreshOutdatedGeoData(autoUpdateState);
      }
    } catch (_) {
      if (!_paused) ygLogger('Data update check failed');
    } finally {
      _running = null;
      finished.complete();
    }
  }

  Future<void> _refreshOutdatedGeoData(AutoUpdateState autoUpdateState) async {
    final interval = autoUpdateState.geoDataInterval.value;
    final now = DateTime.now();
    final systemGeoData = await SystemGeoDatState.system;
    if (_paused) return;
    if (_expired(systemGeoData, now, interval)) {
      try {
        await GeoDataService().refreshSystemGeoDat(systemGeoData);
      } catch (_) {
        // Keep the default pair due, but do not starve independent custom data.
        ygLogger('Default Geodata update failed');
      }
    }

    final customGeoData = await AppDatabase().geoDataDao.allRows;
    for (final geoData in customGeoData) {
      if (_paused) break;
      if (now.difference(geoData.timestamp).inHours >= interval) {
        await GeoDataService().updateGeoDat(geoData);
      }
    }
  }

  bool _expired(List<GeoDataData> geoData, DateTime now, int interval) {
    if (geoData.isEmpty) {
      return false;
    }
    for (final item in geoData) {
      if (now.difference(item.timestamp).inHours >= interval) {
        return true;
      }
    }
    return false;
  }
}
