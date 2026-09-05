import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/data_update/service.dart';

class BackgroundTaskService with WidgetsBindingObserver {
  static final BackgroundTaskService _singleton =
      BackgroundTaskService._internal();

  factory BackgroundTaskService() => _singleton;

  BackgroundTaskService._internal();

  //==========================
  Timer? _timer;
  StreamSubscription<VpnStatus>? _vpnStatusSubscription;
  var _vpnConnected = false;
  var _observingLifecycle = false;

  void init() {
    if (_timer != null) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
    _vpnStatusSubscription ??= AppFlutterApi().vpnStatusController.stream
        .listen(_vpnStatusChanged);
    final interval = const Duration(hours: 1);
    _timer = Timer.periodic(interval, (_) => checkDataUpdate());

    // Check for updates immediately on startup
    unawaited(checkDataUpdate());
  }

  void dispose() {
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    _timer?.cancel();
    _timer = null;
    _vpnStatusSubscription?.cancel();
    _vpnStatusSubscription = null;
    _vpnConnected = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(checkDataUpdate());
  }

  Future<void> checkDataUpdate({
    bool updateSubscription = true,
    bool updateGeoData = true,
  }) async {
    await DataUpdateService().checkAndRun(
      updateSubscription: updateSubscription,
      updateGeoData: updateGeoData,
    );
  }

  void _vpnStatusChanged(VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        if (_vpnConnected) return;
        _vpnConnected = true;
        unawaited(_checkDataUpdateAfterVpnConnected());
        break;
      default:
        _vpnConnected = false;
        break;
    }
  }

  Future<void> _checkDataUpdateAfterVpnConnected() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!_vpnConnected) {
      return;
    }
    await checkDataUpdate();
  }
}
