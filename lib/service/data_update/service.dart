import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/system_state.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:onexray/service/subscription/service.dart';

class DataUpdateService {
  static final DataUpdateService _singleton = DataUpdateService._internal();

  factory DataUpdateService() => _singleton;

  DataUpdateService._internal();

  var _running = false;

  Future<void> checkAndRun({
    bool updateSubscription = true,
    bool updateGeoData = true,
    bool vpnConnected = false,
  }) async {
    if (_running || AppEventBus.instance.state.downloading) {
      return;
    }

    _running = true;
    final eventBus = AppEventBus.instance;
    var downloading = false;
    try {
      final autoUpdateState = AutoUpdateState();
      await autoUpdateState.readFromPreferences();
      final shouldUpdateSubscription =
          updateSubscription && autoUpdateState.subscriptionEnabled;
      final shouldUpdateGeoData =
          updateGeoData && autoUpdateState.geoDataEnable;
      if (!shouldUpdateSubscription && !shouldUpdateGeoData) return;
      eventBus.updateDownloading(true);
      downloading = true;
      if (shouldUpdateSubscription) {
        await SubscriptionService().refreshOutdatedSubscription(
          autoUpdateState: autoUpdateState,
          updateDownloading: false,
        );
      }
      if (shouldUpdateGeoData) {
        await _refreshOutdatedGeoData(autoUpdateState);
      }
    } catch (_) {
      ygLogger('Data update check failed');
    } finally {
      if (downloading) eventBus.updateDownloading(false);
      _running = false;
    }
  }

  Future<void> _refreshOutdatedGeoData(AutoUpdateState autoUpdateState) async {
    final interval = autoUpdateState.geoDataInterval.value;
    final now = DateTime.now();
    final systemGeoData = await SystemGeoDatState.system;
    if (_expired(systemGeoData, now, interval)) {
      try {
        await GeoDataService().refreshSystemGeoDat(
          systemGeoData,
          updateDownloading: false,
        );
      } catch (_) {
        // Keep the default pair due, but do not starve independent custom data.
        ygLogger('Default Geodata update failed');
      }
    }

    final customGeoData = await AppDatabase().geoDataDao.allRows;
    for (final geoData in customGeoData) {
      if (now.difference(geoData.timestamp).inHours >= interval) {
        await GeoDataService().updateGeoDat(geoData, updateDownloading: false);
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
