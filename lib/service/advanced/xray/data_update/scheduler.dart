import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/advanced/xray/data_update/service.dart';
import 'package:onexray/service/settings/backup/service.dart';

class BackgroundTaskService with WidgetsBindingObserver {
  static final BackgroundTaskService _singleton =
      BackgroundTaskService._internal();

  factory BackgroundTaskService() => _singleton;

  BackgroundTaskService._internal()
    : _updates = DataUpdateService(),
      _checkBackup = (() => BackupService().checkAutomatic());

  BackgroundTaskService.forTesting(
    this._updates, {
    Future<void> Function()? checkBackup,
  }) : _checkBackup = checkBackup ?? _noBackup;

  final DataUpdateService _updates;
  final Future<void> Function() _checkBackup;
  static Future<void> _noBackup() async {}

  //==========================
  Timer? _timer;
  Timer? _connectedCheck;
  StreamSubscription<VpnStatus>? _vpnStatusSubscription;
  var _vpnConnected = false;
  var _observingLifecycle = false;

  void init({bool vpnConnected = false}) {
    if (_timer != null) {
      return;
    }
    _vpnConnected = vpnConnected;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
    _vpnStatusSubscription ??= AppFlutterApi().vpnStatusController.stream
        .listen(
          _vpnStatusChanged,
          onError: (Object _) {
            // The coordinator reports status errors; they are not connection changes.
          },
        );
    final interval = const Duration(hours: 1);
    _timer = Timer.periodic(interval, (_) => checkDataUpdate());

    // Backup and subscriptions do not require VPN; Geodata needs a connection.
    unawaited(checkDataUpdate());
  }

  void dispose() {
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    _timer?.cancel();
    _timer = null;
    _connectedCheck?.cancel();
    _connectedCheck = null;
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
    await Future.wait([
      _independentCheck(
        () => _updates.checkAndRun(
          updateSubscription: updateSubscription,
          updateGeoData: updateGeoData && _vpnConnected,
          isVpnConnected: () => _vpnConnected,
        ),
      ),
      _independentCheck(_checkBackup),
    ]);
  }

  Future<void> _independentCheck(Future<void> Function() check) async {
    try {
      await check();
    } catch (error) {
      ygLogger('Background check failed: ${failureDetails(error)}');
    }
  }

  void _vpnStatusChanged(VpnStatus status) {
    switch (status) {
      case VpnStatus.connected:
        if (_vpnConnected) return;
        _vpnConnected = true;
        _connectedCheck = Timer(const Duration(seconds: 3), () {
          _connectedCheck = null;
          unawaited(checkDataUpdate());
        });
        break;
      default:
        _vpnConnected = false;
        _connectedCheck?.cancel();
        _connectedCheck = null;
        break;
    }
  }
}
