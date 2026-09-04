import 'dart:async';

import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/logger.dart';

class AppFlutterApi extends BridgeFlutterApi {
  static final AppFlutterApi _singleton = AppFlutterApi._internal();

  factory AppFlutterApi() => _singleton;

  AppFlutterApi._internal();

  final vpnStatusController = StreamController<VpnStatus>.broadcast();
  VpnStatus? _lastLoggedVpnStatus;

  @override
  Future<void> vpnStatusChanged(VpnStatus status) async {
    if (_lastLoggedVpnStatus != status) {
      ygLogger("vpnStatusChanged ${status.name}");
      _lastLoggedVpnStatus = status;
    }
    vpnStatusController.add(status);
  }

  RefreshVpnResult? _lastLoggedRefreshVpnResult;

  @override
  Future<void> refreshVpn(RefreshVpnResult result) async {
    if (_lastLoggedRefreshVpnResult != result) {
      ygLogger("refreshVpn ${result.name}");
      _lastLoggedRefreshVpnResult = result;
    }
  }
}
