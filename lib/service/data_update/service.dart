import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/geo_data/system_state.dart';
import 'package:onexray/service/sub_update/state.dart';
import 'package:onexray/service/subscription/service.dart';

class DataUpdateService {
  static final DataUpdateService _singleton = DataUpdateService._internal();

  factory DataUpdateService() => _singleton;

  DataUpdateService._internal();

  var _running = false;

  Future<void> checkAndRun() async {
    if (_running || AppEventBus.instance.state.downloading) {
      return;
    }

    final subUpdateState = SubUpdateState();
    await subUpdateState.readFromPreferences();
    if (!subUpdateState.enable && !subUpdateState.geoDataEnable) {
      return;
    }

    _running = true;
    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);
    try {
      if (subUpdateState.enable) {
        await SubscriptionService().refreshOutdatedSubscription(
          subUpdateState: subUpdateState,
          updateDownloading: false,
        );
      }
      if (subUpdateState.geoDataEnable) {
        await _refreshOutdatedGeoData(subUpdateState);
      }
    } catch (e) {
      ygLogger("DataUpdateService checkAndRun error: $e");
    } finally {
      eventBus.updateDownloading(false);
      _running = false;
    }
  }

  Future<void> _refreshOutdatedGeoData(SubUpdateState subUpdateState) async {
    final interval = subUpdateState.geoDataInterval.value;
    final now = DateTime.now();
    final systemGeoData = await SystemGeoDatState.system;
    if (_expired(systemGeoData, now, interval)) {
      await GeoDataService().refreshSystemGeoDat(
        systemGeoData,
        updateDownloading: false,
      );
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
