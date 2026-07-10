import 'dart:async';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_writer.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/menu/tray/service.dart';
import 'package:onexray/service/notification/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/vpn/connectivity.dart';
import 'package:onexray/service/vpn/runtime_config.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';

final class VpnService {
  static final VpnService _singleton = VpnService._internal();

  factory VpnService() => _singleton;

  VpnService._internal();

  //=================================
  var _lastConfigId = DBConstants.defaultId;
  var _pendingConfigId = DBConstants.defaultId;
  var _vpnRunning = false;
  var _lastVpnStatus = VpnStatus.disconnected;
  var _runningMode = CoreRunMode.tun;
  var _pendingRunMode = CoreRunMode.tun;
  late final _connectivity = VpnConnectivityService(() => _vpnRunning);
  late final _runtimeConfig = XrayRuntimeConfigService();

  bool get vpnRunning => _vpnRunning;

  Future<void> asyncInit() async {
    final eventBus = AppEventBus.instance;
    final savedRunningId = await PreferencesKey().readRunningConfigId();
    eventBus.updateRunningId(savedRunningId);

    _lastConfigId = await PreferencesKey().readLastConfigId();
    _runningMode = await PreferencesKey().readCoreRunMode();
    _pendingRunMode = _runningMode;

    _listenVpnStatus();
  }

  void dispose() {
    _connectivity.stop();
    final vpnStatusSubscription = _vpnStatusSubscription;
    _vpnStatusSubscription = null;
    unawaited(vpnStatusSubscription?.cancel() ?? Future.value());
  }

  StreamSubscription<VpnStatus>? _vpnStatusSubscription;

  void _listenVpnStatus() {
    if (_vpnStatusSubscription != null) {
      return;
    }
    ygLogger("_listenVpnStatus");
    _vpnStatusSubscription = AppFlutterApi().vpnStatusController.stream.listen(
      _vpnStatusChanged,
    );
  }

  Future<void> refreshVpnStatus() async {
    final mode = await PreferencesKey().readCoreRunMode();
    if (mode == CoreRunMode.proxy) {
      await _refreshProxyCoreStatus();
      return;
    }
    final result = await AppHostApi().readVpnStatus();
    _applyNativeCommandResult(result);
  }

  Future<void> _refreshProxyCoreStatus() async {
    final running = await AppHostApi().getXrayState();
    _pendingRunMode = CoreRunMode.proxy;
    if (running) {
      await _vpnStatusChanged(VpnStatus.connected);
    } else {
      await _vpnStatusChanged(VpnStatus.disconnected);
    }
  }

  Future<void> _vpnStatusChanged(VpnStatus status) async {
    _lastVpnStatus = status;
    final eventBus = AppEventBus.instance;
    switch (status) {
      case VpnStatus.disconnecting:
        eventBus.updateVpnActionState(VpnActionState.disconnecting);
        break;
      case VpnStatus.disconnected:
        _vpnRunning = false;
        _pendingConfigId = DBConstants.defaultId;
        eventBus.updatePendingConfigId(DBConstants.defaultId);
        eventBus.updateVpnActionState(VpnActionState.idle);
        await _updateRunningId(DBConstants.defaultId);
        await TrayService().refreshTrayManager();
        _connectivity.stop();
        break;
      case VpnStatus.connecting:
        eventBus.updateVpnActionState(VpnActionState.connecting);
        break;
      case VpnStatus.connected:
        _vpnRunning = true;
        _runningMode = _pendingRunMode;
        eventBus.updateVpnActionState(VpnActionState.connected);
        final runningId = _pendingConfigId == DBConstants.defaultId
            ? _lastConfigId
            : _pendingConfigId;
        await _updateRunningId(runningId);
        _pendingConfigId = DBConstants.defaultId;
        eventBus.updatePendingConfigId(DBConstants.defaultId);
        await TrayService().refreshTrayManager();
        await _connectivity.start();
        break;
    }
  }

  Future<void> _updateRunningId(int id) async {
    await PreferencesKey().saveRunningConfigId(id);
    final eventBus = AppEventBus.instance;
    eventBus.updateRunningId(id);
  }

  Future<void> _updateLastConfigId(int id) async {
    await PreferencesKey().saveLastConfigId(id);
    _lastConfigId = id;
  }

  Future<NativeVpnCommandResult> restartCurrentVpn() async {
    final eventBus = AppEventBus.instance;
    final configId = eventBus.state.runningId;
    await stopDefaultVpn();
    if (configId == DBConstants.defaultId) {
      return _commandSuccess();
    }
    return startVpn(configId);
  }

  Future<NativeVpnCommandResult> startDefaultVpn() async {
    final eventBus = AppEventBus.instance;
    if (eventBus.state.runningId != DBConstants.defaultId) {
      return _commandSuccess();
    }

    final db = AppDatabase();
    if (_lastConfigId == DBConstants.defaultId) {
      return _startRandomVpn();
    } else {
      final config = await db.coreConfigDao.searchRow(_lastConfigId);
      if (config == null) {
        return _startRandomVpn();
      } else {
        return startVpn(config.id);
      }
    }
  }

  Future<NativeVpnCommandResult> _startRandomVpn() async {
    final db = AppDatabase();
    final config = await db.coreConfigDao.randomConfig();
    if (config == null) {
      await NotificationService().pushNotification(
        appLocalizationsNoContext().vpnNoConfig,
      );
      return _commandFailed(appLocalizationsNoContext().vpnNoConfig);
    } else {
      return startVpn(config.id);
    }
  }

  Future<NativeVpnCommandResult> stopDefaultVpn() async {
    return _stopCurrentVpn();
  }

  Future<NativeVpnCommandResult> startVpn(int configId) async {
    final eventBus = AppEventBus.instance;
    final coreRunMode = await PreferencesKey().readCoreRunMode();
    if (configId == DBConstants.defaultId) {
      return stopDefaultVpn();
    }
    if (configId == eventBus.state.runningId) {
      return stopDefaultVpn();
    }

    _pendingConfigId = configId;
    eventBus.updatePendingConfigId(configId);
    eventBus.updateVpnActionState(VpnActionState.preparing);
    eventBus.updateVpnErrorMessage("");

    if (coreRunMode == CoreRunMode.tun) {
      final permission = await _ensurePlatformPermissionForUserAction();
      if (permission.state == PlatformPermissionState.failed) {
        final message =
            permission.message ??
            appLocalizationsNoContext().vpnPlatformPermissionCheckFailed;
        await _handleStartFailure(message);
        return _commandFailed(message);
      }
      if (!_permissionAllowsStart(permission)) {
        eventBus.updatePlatformPermission(permission);
        eventBus.updateVpnActionState(
          VpnActionState.waitingForPlatformPermission,
        );
        return _waitingForPermission(permission);
      }
    }

    if (eventBus.state.runningId != DBConstants.defaultId ||
        _lastVpnStatus == VpnStatus.connected ||
        _lastVpnStatus == VpnStatus.connecting) {
      final stopResult = await _stopCurrentVpn();
      if (stopResult.state == NativeVpnCommandState.failed) {
        return stopResult;
      }
      _pendingConfigId = configId;
      eventBus.updatePendingConfigId(configId);
      eventBus.updateVpnActionState(VpnActionState.preparing);
    }

    final db = AppDatabase();
    final outbound = await db.coreConfigDao.searchRow(configId);
    if (outbound == null) {
      final message = appLocalizationsNoContext().vpnSelectOneConfig;
      await _handleStartFailure(message);
      return _commandFailed(message);
    }

    try {
      final result = await _realStartXray(outbound);
      if (result.state == NativeVpnCommandState.waitingForPlatformPermission) {
        if (result.permission != null) {
          eventBus.updatePlatformPermission(result.permission!);
        }
        eventBus.updateVpnActionState(
          VpnActionState.waitingForPlatformPermission,
        );
        return result;
      }
      if (result.state == NativeVpnCommandState.failed) {
        await _handleStartFailure(
          result.message ?? appLocalizationsNoContext().vpnStartFailed,
        );
        return result;
      }
      if (_lastVpnStatus != VpnStatus.connected) {
        eventBus.updateVpnActionState(VpnActionState.connecting);
      }
      final connected = await _waitForVpnStatus({VpnStatus.connected});
      if (!connected) {
        final message = appLocalizationsNoContext().vpnStartTimeout;
        await _handleStartFailure(message);
        return _commandFailed(message);
      }
      eventBus.updateVpnActionState(VpnActionState.connected);
      return result;
    } on XrayRuntimeConfigException catch (e) {
      await _handleStartFailure(e.message);
      return _commandFailed(e.message);
    }
  }

  Future<NativeVpnCommandResult> _stopCurrentVpn() async {
    final eventBus = AppEventBus.instance;
    _pendingConfigId = DBConstants.defaultId;
    eventBus.updatePendingConfigId(DBConstants.defaultId);
    eventBus.updateVpnActionState(VpnActionState.disconnecting);
    final result = await _stopCurrentCore();
    if (result.state == NativeVpnCommandState.failed) {
      eventBus.updateVpnActionState(VpnActionState.failed);
      eventBus.updateVpnErrorMessage(
        result.message ?? appLocalizationsNoContext().vpnStopFailed,
      );
      return result;
    }
    final disconnected = await _waitForVpnStatus({
      VpnStatus.disconnected,
    }, timeoutSeconds: 5);
    if (!disconnected) {
      final message = appLocalizationsNoContext().vpnStopFailed;
      eventBus.updateVpnActionState(VpnActionState.failed);
      eventBus.updateVpnErrorMessage(message);
      return _commandFailed(message);
    }
    await _updateRunningId(DBConstants.defaultId);
    eventBus.updateVpnActionState(VpnActionState.idle);
    return result;
  }

  Future<NativeVpnCommandResult> switchRunMode(CoreRunMode mode) async {
    final preferences = PreferencesKey();
    final currentMode = await preferences.readCoreRunMode();
    if (currentMode == mode) {
      return _commandSuccess();
    }

    final eventBus = AppEventBus.instance;
    final runningId = eventBus.state.runningId;
    if (runningId != DBConstants.defaultId ||
        _lastVpnStatus == VpnStatus.connected ||
        _lastVpnStatus == VpnStatus.connecting) {
      final stopResult = await _stopCurrentVpn();
      if (stopResult.state == NativeVpnCommandState.failed) {
        return stopResult;
      }
    }

    await preferences.saveCoreRunMode(mode);
    eventBus.updateCoreRunMode(mode);
    await TrayService().refreshTrayManager();

    if (runningId == DBConstants.defaultId) {
      return _commandSuccess();
    }
    return startVpn(runningId);
  }

  Future<NativeVpnCommandResult> _stopCurrentCore() async {
    if (_runningMode == CoreRunMode.proxy) {
      return _stopProxyCore();
    }
    final result = await AppHostApi().stopVpn();
    _applyNativeCommandResult(result);
    return result;
  }

  Future<NativeVpnCommandResult> _stopProxyCore() async {
    await _vpnStatusChanged(VpnStatus.disconnecting);
    final error = await AppHostApi().stopXray();
    if (error.isNotEmpty) {
      return _commandFailed(appLocalizationsNoContext().vpnStopFailed);
    }
    await _vpnStatusChanged(VpnStatus.disconnected);
    return _commandSuccess();
  }

  Future<PlatformPermissionResult>
  _ensurePlatformPermissionForUserAction() async {
    final eventBus = AppEventBus.instance;
    final query = await AppHostApi().queryPlatformPermission();
    eventBus.updatePlatformPermission(query);
    if (_permissionAllowsStart(query) ||
        query.state == PlatformPermissionState.failed) {
      return query;
    }
    final request = await AppHostApi().requestPlatformPermission();
    eventBus.updatePlatformPermission(request);
    return request;
  }

  bool _permissionAllowsStart(PlatformPermissionResult permission) {
    return permission.state == PlatformPermissionState.notRequired ||
        permission.state == PlatformPermissionState.granted;
  }

  void _applyNativeCommandResult(NativeVpnCommandResult result) {
    final eventBus = AppEventBus.instance;
    final permission = result.permission;
    if (permission != null) {
      eventBus.updatePlatformPermission(permission);
    }
    switch (result.state) {
      case NativeVpnCommandState.success:
        break;
      case NativeVpnCommandState.waitingForPlatformPermission:
        eventBus.updateVpnActionState(
          VpnActionState.waitingForPlatformPermission,
        );
        break;
      case NativeVpnCommandState.failed:
        eventBus.updateVpnActionState(VpnActionState.failed);
        eventBus.updateVpnErrorMessage(
          result.message ?? appLocalizationsNoContext().vpnCommandFailed,
        );
        break;
    }
  }

  Future<void> _handleStartFailure(String message) async {
    final eventBus = AppEventBus.instance;
    _pendingConfigId = DBConstants.defaultId;
    eventBus.updatePendingConfigId(DBConstants.defaultId);
    eventBus.updateVpnActionState(VpnActionState.failed);
    eventBus.updateVpnErrorMessage(message);
    await _updateRunningId(DBConstants.defaultId);
    ToastService().showToast(message);
    _connectivity.stop();
  }

  Future<bool> _waitForVpnStatus(
    Set<VpnStatus> statuses, {
    int timeoutSeconds = 15,
  }) async {
    if (statuses.contains(_lastVpnStatus)) {
      return true;
    }
    try {
      await AppFlutterApi().vpnStatusController.stream
          .firstWhere(statuses.contains)
          .timeout(Duration(seconds: timeoutSeconds));
      return true;
    } catch (_) {
      return statuses.contains(_lastVpnStatus);
    }
  }

  NativeVpnCommandResult _commandSuccess() {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.success,
      permission: PlatformPermissionResult(
        kind: PlatformPermissionKind.none,
        state: PlatformPermissionState.notRequired,
      ),
    );
  }

  NativeVpnCommandResult _commandFailed(String message) {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.failed,
      permission: PlatformPermissionResult(
        kind: PlatformPermissionKind.none,
        state: PlatformPermissionState.notRequired,
      ),
      message: message,
    );
  }

  NativeVpnCommandResult _waitingForPermission(
    PlatformPermissionResult permission,
  ) {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.waitingForPlatformPermission,
      permission: permission,
    );
  }

  Future<NativeVpnCommandResult> _realStartXray(CoreConfigData config) async {
    await _updateLastConfigId(config.id);
    await PreferencesKey().saveVpnStartTimestamp();

    final runtime = await _runtimeConfig.prepare(config);
    _pendingRunMode = runtime.mode;
    switch (runtime.mode) {
      case CoreRunMode.tun:
        return _makeVpnRequestAndStart(
          runtime.coreInvokeText,
          runtime.ports,
          runtime.tunSettings,
        );
      case CoreRunMode.proxy:
        return _makeProxyRequestAndStart(runtime.coreInvokeText, runtime.ports);
    }
  }

  Future<NativeVpnCommandResult> _makeProxyRequestAndStart(
    String coreInvokeText,
    XrayPorts port,
  ) async {
    final request = StartVpnRequest(
      null,
      port.pingPort,
      port.pingAuth,
      port.metricsPort,
      coreInvokeText,
    );
    await request.writeToStartFile();

    await _vpnStatusChanged(VpnStatus.connecting);
    final error = await AppHostApi().runXray(coreInvokeText);
    if (error.isNotEmpty) {
      await _vpnStatusChanged(VpnStatus.disconnected);
      return _commandFailed(error);
    }
    await _vpnStatusChanged(VpnStatus.connected);
    return _commandSuccess();
  }

  Future<NativeVpnCommandResult> _makeVpnRequestAndStart(
    String coreInvokeText,
    XrayPorts port,
    TunSettingsState tunSettingsState,
  ) async {
    final request = StartVpnRequest(
      tunSettingsState.tunJson,
      port.pingPort,
      port.pingAuth,
      port.metricsPort,
      coreInvokeText,
    );
    await request.writeToStartFile();

    final result = await AppHostApi().startVpn();
    _applyNativeCommandResult(result);
    return result;
  }

  Future<void> retryConnectivityTest() {
    return _connectivity.retry();
  }
}
