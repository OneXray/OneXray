import 'dart:async';

import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/data_update/service.dart';

class BackgroundTaskService {
  static final BackgroundTaskService _singleton =
      BackgroundTaskService._internal();

  factory BackgroundTaskService() => _singleton;

  BackgroundTaskService._internal();

  //==========================
  Timer? _timer;
  StreamSubscription<VpnStatus>? _vpnStatusSubscription;
  var _vpnConnected = false;

  void init() {
    if (_timer != null) {
      return;
    }
    _vpnStatusSubscription ??= AppFlutterApi().vpnStatusController.stream
        .listen(_vpnStatusChanged);
    final interval = const Duration(hours: 1);
    _timer = Timer.periodic(interval, (_) => checkDataUpdate());

    // Check for updates immediately on startup
    unawaited(checkDataUpdate());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _vpnStatusSubscription?.cancel();
    _vpnStatusSubscription = null;
    _vpnConnected = false;
  }

  Future<void> checkDataUpdate({
    bool updateSubscription = true,
    bool updateGeoData = true,
    bool? vpnConnected,
  }) async {
    await DataUpdateService().checkAndRun(
      updateSubscription: updateSubscription,
      updateGeoData: updateGeoData,
      vpnConnected: vpnConnected ?? _vpnConnected,
    );
  }

  void _vpnStatusChanged(VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        _vpnConnected = true;
        unawaited(_checkGeoDataUpdateAfterVpnConnected());
        break;
      default:
        _vpnConnected = false;
        break;
    }
  }

  Future<void> _checkGeoDataUpdateAfterVpnConnected() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!_vpnConnected) {
      return;
    }
    await checkDataUpdate(updateSubscription: false, vpnConnected: true);
  }
}
