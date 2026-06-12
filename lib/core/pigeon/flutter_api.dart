import 'dart:async';

import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/logger.dart';

class AppFlutterApi extends BridgeFlutterApi {
  static final AppFlutterApi _singleton = AppFlutterApi._internal();

  factory AppFlutterApi() => _singleton;

  AppFlutterApi._internal();

  final vpnStatusController = StreamController<VpnStatus>.broadcast();

  @override
  Future<void> vpnStatusChanged(VpnStatus status) async {
    ygLogger("vpnStatusChanged ${status.name}");
    vpnStatusController.add(status);
  }

  final refreshVpnController = StreamController<RefreshVpnResult>.broadcast();

  RefreshVpnResult? _lastRefreshVpnResult;

  RefreshVpnResult? consumeRefreshVpnResult() {
    final result = _lastRefreshVpnResult;
    _lastRefreshVpnResult = null;
    return result;
  }

  @override
  Future<void> refreshVpn(RefreshVpnResult result) async {
    ygLogger("refreshVpn ${result.name}");
    _lastRefreshVpnResult = result;
    refreshVpnController.add(result);
  }
}
