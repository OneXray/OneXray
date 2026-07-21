import 'dart:async';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_writer.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/menu/tray/service.dart';
import 'package:onexray/service/notification/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/vpn/command_serial_executor.dart';
import 'package:onexray/service/vpn/connectivity.dart';
import 'package:onexray/service/vpn/running_config_id_writer.dart';
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
  var _runningRoutingMode = CoreRoutingMode.rule;
  var _pendingRoutingMode = CoreRoutingMode.rule;
  var _staleDesktopCoreCleanupRequired = false;
  final _commands = CommandSerialExecutor();
  late final _runningConfigIdWriter = RunningConfigIdWriter(
    persist: PreferencesKey().saveRunningConfigId,
    apply: (value) => AppEventBus.instance.updateRunningId(value),
    readCurrent: () => AppEventBus.instance.state.runningId,
    isCurrent: _commands.isCurrent,
  );
  late final _connectivity = VpnConnectivityService(() => _vpnRunning);
  late final _runtimeConfig = XrayRuntimeConfigService();
  Future<void> _statusTail = Future<void>.value();
  Future<void>? _initFuture;

  bool get vpnRunning => _vpnRunning;
  CoreRunMode get _selectedRunMode =>
      CoreRunModePolicy.resolve(AppEventBus.instance.state.coreRunMode);

  Future<void> asyncInit() {
    final initFuture = _initFuture;
    if (initFuture != null) {
      return initFuture;
    }
    final nextInitFuture = _asyncInit();
    _initFuture = nextInitFuture;
    return nextInitFuture;
  }

  Future<void> _asyncInit() async {
    final eventBus = AppEventBus.instance;
    final preferences = PreferencesKey();
    final cleanupResult = await AppHostApi().cleanupStaleDesktopCore();
    _staleDesktopCoreCleanupRequired = cleanupResult == false;
    var savedRunningId = await preferences.readRunningConfigId();
    if (cleanupResult != null) {
      if (!cleanupResult) {
        ygLogger('stale desktop core cleanup failed');
      }
      savedRunningId = DBConstants.defaultId;
      await preferences.saveRunningConfigId(savedRunningId);
      await _clearStartSnapshot();
    }
    eventBus.updateRunningId(savedRunningId);

    _lastConfigId = await preferences.readLastConfigId();
    _runningMode = CoreRunMode.tun;
    _pendingRunMode = _selectedRunMode;
    _runningRoutingMode = await preferences.readCoreRoutingMode();
    _pendingRoutingMode = _runningRoutingMode;

    _listenVpnStatus();
    if (_staleDesktopCoreCleanupRequired) {
      _showStaleDesktopCoreCleanupFailure();
    }
    await _commands.run(_refreshVpnStatus);
  }

  void dispose() {
    _initFuture = null;
    _commands.invalidate();
    _connectivity.stop();
    final vpnStatusSubscription = _vpnStatusSubscription;
    _vpnStatusSubscription = null;
    unawaited(vpnStatusSubscription?.cancel() ?? Future.value());
  }

  StreamSubscription<VpnStatus>? _vpnStatusSubscription;

  Future<T> _runCommand<T>(Future<T> Function(int generation) command) async {
    await asyncInit();
    return _commands.run(command);
  }

  void _listenVpnStatus() {
    if (_vpnStatusSubscription != null) {
      return;
    }
    ygLogger("_listenVpnStatus");
    _vpnStatusSubscription = AppFlutterApi().vpnStatusController.stream.listen(
      (status) => unawaited(_queueVpnStatus(status)),
    );
  }

  Future<void> refreshVpnStatus() => _runCommand(_refreshVpnStatus);

  Future<void> _refreshVpnStatus(int generation) async {
    if (!await _ensureStaleDesktopCoreCleaned(generation)) {
      return;
    }
    final mode = _isCoreActive ? _runningMode : _selectedRunMode;
    if (!_commands.isCurrent(generation)) {
      return;
    }
    if (mode == CoreRunMode.proxy) {
      await _refreshProxyCoreStatus(generation);
      return;
    }
    final result = await AppHostApi().readVpnStatus();
    if (!_commands.isCurrent(generation)) {
      return;
    }
    _applyNativeCommandResult(result);
    await _drainStatusUpdates(generation);
  }

  Future<void> _refreshProxyCoreStatus(int generation) async {
    final running = await AppHostApi().getXrayState();
    if (!_commands.isCurrent(generation)) {
      return;
    }
    _pendingRunMode = CoreRunMode.proxy;
    if (running) {
      await _queueVpnStatus(VpnStatus.connected);
    } else {
      await _queueVpnStatus(VpnStatus.disconnected);
    }
  }

  Future<void> _queueVpnStatus(VpnStatus status) {
    _lastVpnStatus = status;
    final generation = _commands.currentGeneration;
    final update = _statusTail.then((_) async {
      if (!_commands.isCurrent(generation)) {
        return;
      }
      try {
        await _applyVpnStatus(status, generation);
      } catch (error, stackTrace) {
        ygLogger('apply VPN status failed: $error\n$stackTrace');
      }
    });
    _statusTail = update;
    return update;
  }

  Future<void> _applyVpnStatus(VpnStatus status, int generation) async {
    if (!_commands.isCurrent(generation)) {
      return;
    }
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
        await _updateRunningId(DBConstants.defaultId, generation);
        if (!_commands.isCurrent(generation)) {
          return;
        }
        await TrayService().refreshTrayManager();
        _connectivity.stop();
        break;
      case VpnStatus.connecting:
        eventBus.updateVpnActionState(VpnActionState.connecting);
        break;
      case VpnStatus.connected:
        _vpnRunning = true;
        _runningMode = _pendingRunMode;
        _runningRoutingMode = _pendingRoutingMode;
        eventBus.updateCoreRoutingMode(_runningRoutingMode);
        eventBus.updateVpnActionState(VpnActionState.connected);
        final runningId = _runningRoutingMode == CoreRoutingMode.direct
            ? DBConstants.defaultId
            : _pendingConfigId == DBConstants.defaultId
            ? _lastConfigId
            : _pendingConfigId;
        await _updateRunningId(runningId, generation);
        if (!_commands.isCurrent(generation)) {
          return;
        }
        _pendingConfigId = DBConstants.defaultId;
        eventBus.updatePendingConfigId(DBConstants.defaultId);
        await TrayService().refreshTrayManager();
        unawaited(_startConnectivity());
        break;
    }
  }

  Future<void> _startConnectivity() async {
    try {
      await _connectivity.start();
    } catch (error, stackTrace) {
      ygLogger('start VPN connectivity services failed: $error\n$stackTrace');
    }
  }

  Future<void> _updateRunningId(int id, int generation) =>
      _runningConfigIdWriter.write(id, generation);

  Future<void> _updateLastConfigId(int id) async {
    await PreferencesKey().saveLastConfigId(id);
    _lastConfigId = id;
  }

  Future<NativeVpnCommandResult> startDefaultVpn() =>
      _runCommand(_startDefaultVpn);

  Future<NativeVpnCommandResult> _startDefaultVpn(int generation) async {
    if (_isCoreActive) {
      return _commandSuccess();
    }

    final routingMode = await PreferencesKey().readCoreRoutingMode();
    if (routingMode == CoreRoutingMode.direct) {
      return _startVpn(_lastConfigId, generation);
    }

    final db = AppDatabase();
    if (_lastConfigId == DBConstants.defaultId) {
      return _startRandomVpn(generation);
    } else {
      final config = await db.coreConfigDao.searchRow(_lastConfigId);
      if (config == null) {
        return _startRandomVpn(generation);
      } else {
        return _startVpn(config.id, generation);
      }
    }
  }

  Future<NativeVpnCommandResult> _startRandomVpn(int generation) async {
    final db = AppDatabase();
    final config = await db.coreConfigDao.randomConfig();
    if (config == null) {
      await NotificationService().pushNotification(
        appLocalizationsNoContext().vpnNoConfig,
      );
      return _commandFailed(appLocalizationsNoContext().vpnNoConfig);
    } else {
      return _startVpn(config.id, generation);
    }
  }

  Future<NativeVpnCommandResult> stopDefaultVpn() =>
      _runCommand(_stopCurrentVpn);

  Future<NativeVpnCommandResult> startVpn(int configId) =>
      _runCommand((generation) => _startVpn(configId, generation));

  Future<NativeVpnCommandResult> _startVpn(int configId, int generation) async {
    final eventBus = AppEventBus.instance;
    final coreRunMode = _selectedRunMode;
    final routingMode = await PreferencesKey().readCoreRoutingMode();
    if (!_commands.isCurrent(generation)) {
      return _commandFailed(appLocalizationsNoContext().vpnCommandFailed);
    }
    if (configId == DBConstants.defaultId &&
        (routingMode != CoreRoutingMode.direct || _isCoreActive)) {
      return _stopCurrentVpn(generation);
    }
    if (routingMode == CoreRoutingMode.direct && _isCoreActive) {
      return _stopCurrentVpn(generation);
    }
    if (!await _ensureStaleDesktopCoreCleaned(generation)) {
      return _commandFailed(
        appLocalizationsNoContext().vpnStaleCoreCleanupFailed,
      );
    }
    if (routingMode != CoreRoutingMode.direct &&
        configId == eventBus.state.runningId) {
      return _stopCurrentVpn(generation);
    }

    final hadRunningCore = _isCoreActive;

    _pendingRoutingMode = routingMode;
    _pendingConfigId = routingMode == CoreRoutingMode.direct
        ? DBConstants.defaultId
        : configId;
    eventBus.updatePendingConfigId(_pendingConfigId);
    eventBus.updateVpnActionState(VpnActionState.preparing);
    eventBus.updateVpnErrorMessage("");

    var previousCoreStopped = false;
    var startAttempted = false;
    try {
      final outbound = routingMode == CoreRoutingMode.direct
          ? null
          : await AppDatabase().coreConfigDao.searchRow(configId);
      if (routingMode != CoreRoutingMode.direct && outbound == null) {
        final message = appLocalizationsNoContext().vpnSelectOneConfig;
        await _handlePreflightFailure(
          message,
          hadRunningCore: hadRunningCore,
          generation: generation,
        );
        return _commandFailed(message);
      }

      if (coreRunMode == CoreRunMode.tun) {
        final permission = await _ensurePlatformPermissionForUserAction();
        if (permission.state == PlatformPermissionState.failed) {
          final message =
              permission.message ??
              appLocalizationsNoContext().vpnPlatformPermissionCheckFailed;
          await _handlePreflightFailure(
            message,
            hadRunningCore: hadRunningCore,
            generation: generation,
          );
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

      if (hadRunningCore) {
        final stopResult = await _stopCurrentVpn(generation);
        if (stopResult.state == NativeVpnCommandState.failed) {
          return stopResult;
        }
        previousCoreStopped = true;
        _pendingRoutingMode = routingMode;
        _pendingConfigId = routingMode == CoreRoutingMode.direct
            ? DBConstants.defaultId
            : configId;
        eventBus.updatePendingConfigId(_pendingConfigId);
        eventBus.updateVpnActionState(VpnActionState.preparing);
      }

      if (routingMode == CoreRoutingMode.direct &&
          configId != DBConstants.defaultId) {
        await _updateLastConfigId(configId);
      }

      final result = await _realStartXray(
        outbound,
        coreRunMode,
        onStartInvoked: () => startAttempted = true,
      );
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
        await _handleStartedOperationFailure(
          result.message ?? appLocalizationsNoContext().vpnStartFailed,
          coreRunMode,
          generation,
        );
        return result;
      }
      if (_lastVpnStatus != VpnStatus.connected) {
        eventBus.updateVpnActionState(VpnActionState.connecting);
      }
      final connected = await _waitForVpnStatus({
        VpnStatus.connected,
      }, generation);
      if (!connected) {
        final message = appLocalizationsNoContext().vpnStartTimeout;
        await _handleStartedOperationFailure(message, coreRunMode, generation);
        return _commandFailed(message);
      }
      await _drainStatusUpdates(generation);
      eventBus.updateVpnActionState(VpnActionState.connected);
      return result;
    } on XrayRuntimeConfigException catch (e) {
      if (startAttempted) {
        await _handleStartedOperationFailure(
          e.message,
          coreRunMode,
          generation,
        );
      } else {
        await _handleStartFailure(e.message, generation);
      }
      return _commandFailed(e.message);
    } catch (error, stackTrace) {
      ygLogger('start VPN failed: $error\n$stackTrace');
      final message = appLocalizationsNoContext().vpnStartFailed;
      if (startAttempted) {
        await _handleStartedOperationFailure(message, coreRunMode, generation);
      } else if (hadRunningCore && !previousCoreStopped) {
        await _handlePreflightFailure(
          message,
          hadRunningCore: true,
          generation: generation,
        );
      } else {
        await _handleStartFailure(message, generation);
      }
      return _commandFailed(message);
    }
  }

  Future<bool> _ensureStaleDesktopCoreCleaned(int generation) async {
    if (!_staleDesktopCoreCleanupRequired) {
      return true;
    }
    final cleanupResult = await AppHostApi().cleanupStaleDesktopCore();
    if (!_commands.isCurrent(generation)) {
      return false;
    }
    if (cleanupResult == true) {
      _staleDesktopCoreCleanupRequired = false;
      return true;
    }
    _showStaleDesktopCoreCleanupFailure();
    return false;
  }

  void _showStaleDesktopCoreCleanupFailure() {
    final eventBus = AppEventBus.instance;
    eventBus.updateVpnActionState(VpnActionState.failed);
    eventBus.updateVpnErrorMessage(
      appLocalizationsNoContext().vpnStaleCoreCleanupFailed,
    );
  }

  Future<NativeVpnCommandResult> _stopCurrentVpn(int generation) async {
    final eventBus = AppEventBus.instance;
    _pendingConfigId = DBConstants.defaultId;
    eventBus.updatePendingConfigId(DBConstants.defaultId);
    eventBus.updateVpnActionState(VpnActionState.disconnecting);
    final result = await _stopCurrentCore();
    if (result.state == NativeVpnCommandState.failed) {
      await _restoreRunningStateAfterStopFailure(
        result.message ?? appLocalizationsNoContext().vpnStopFailed,
        generation,
      );
      return result;
    }
    var disconnected = await _waitForVpnStatus(
      {VpnStatus.disconnected},
      generation,
      timeoutSeconds: 5,
    );
    if (!disconnected) {
      await _refreshVpnStatus(generation);
      disconnected = await _waitForVpnStatus(
        {VpnStatus.disconnected},
        generation,
        timeoutSeconds: 2,
      );
    }
    if (!disconnected) {
      final message = appLocalizationsNoContext().vpnStopFailed;
      await _restoreRunningStateAfterStopFailure(message, generation);
      return _commandFailed(message);
    }
    await _drainStatusUpdates(generation);
    await _updateRunningId(DBConstants.defaultId, generation);
    eventBus.updateVpnActionState(VpnActionState.idle);
    await _clearStartSnapshot();
    return result;
  }

  Future<NativeVpnCommandResult> switchRunMode(CoreRunMode mode) =>
      _runCommand((generation) => _switchRunMode(mode, generation));

  Future<NativeVpnCommandResult> _switchRunMode(
    CoreRunMode mode,
    int generation,
  ) async {
    mode = CoreRunModePolicy.resolve(mode);
    final currentMode = _selectedRunMode;
    if (currentMode == mode) {
      return _commandSuccess();
    }

    final eventBus = AppEventBus.instance;
    final runningId = eventBus.state.runningId;
    final restartConfigId = runningId == DBConstants.defaultId
        ? _lastConfigId
        : runningId;
    final wasRunning = _isCoreActive;
    if (wasRunning) {
      final stopResult = await _stopCurrentVpn(generation);
      if (stopResult.state == NativeVpnCommandState.failed) {
        return stopResult;
      }
    }

    _pendingRunMode = mode;
    _runningMode = mode;
    eventBus.updateCoreRunMode(mode);
    await TrayService().refreshTrayManager();

    if (!wasRunning) {
      return _commandSuccess();
    }
    return _startVpn(restartConfigId, generation);
  }

  Future<NativeVpnCommandResult> switchRoutingMode(
    CoreRoutingMode mode, {
    required int selectedConfigId,
  }) => _runCommand(
    (generation) => _switchRoutingMode(mode, selectedConfigId, generation),
  );

  Future<NativeVpnCommandResult> _switchRoutingMode(
    CoreRoutingMode mode,
    int selectedConfigId,
    int generation,
  ) async {
    final preferences = PreferencesKey();
    final currentMode = await preferences.readCoreRoutingMode();
    if (currentMode == mode) {
      return _commandSuccess();
    }

    final eventBus = AppEventBus.instance;
    final runningId = eventBus.state.runningId;
    final restartConfigId = runningId != DBConstants.defaultId
        ? runningId
        : selectedConfigId != DBConstants.defaultId
        ? selectedConfigId
        : _lastConfigId;
    final wasRunning = _isCoreActive;
    if (wasRunning) {
      final stopResult = await _stopCurrentVpn(generation);
      if (stopResult.state == NativeVpnCommandState.failed) {
        return stopResult;
      }
    }

    await preferences.saveCoreRoutingMode(mode);
    _pendingRoutingMode = mode;
    _runningRoutingMode = mode;
    eventBus.updateCoreRoutingMode(mode);

    if (!wasRunning) {
      return _commandSuccess();
    }
    if (mode != CoreRoutingMode.direct &&
        restartConfigId == DBConstants.defaultId) {
      return _commandFailed(appLocalizationsNoContext().vpnSelectOneConfig);
    }
    return _startVpn(restartConfigId, generation);
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
    await _queueVpnStatus(VpnStatus.disconnecting);
    final error = await AppHostApi().stopXray();
    if (error.isNotEmpty) {
      return _commandFailed(appLocalizationsNoContext().vpnStopFailed);
    }
    await _queueVpnStatus(VpnStatus.disconnected);
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

  Future<void> _handleStartFailure(String message, int generation) async {
    if (!_commands.isCurrent(generation)) {
      return;
    }
    final eventBus = AppEventBus.instance;
    _pendingConfigId = DBConstants.defaultId;
    eventBus.updatePendingConfigId(DBConstants.defaultId);
    eventBus.updateVpnActionState(VpnActionState.failed);
    eventBus.updateVpnErrorMessage(message);
    await _updateRunningId(DBConstants.defaultId, generation);
    ToastService().showToast(message);
    _connectivity.stop();
    await _clearStartSnapshot();
  }

  Future<void> _handlePreflightFailure(
    String message, {
    required bool hadRunningCore,
    required int generation,
  }) async {
    if (!hadRunningCore) {
      await _handleStartFailure(message, generation);
      return;
    }
    if (!_commands.isCurrent(generation)) {
      return;
    }
    _pendingConfigId = DBConstants.defaultId;
    final eventBus = AppEventBus.instance;
    eventBus.updatePendingConfigId(DBConstants.defaultId);
    eventBus.updateVpnActionState(VpnActionState.connected);
    eventBus.updateVpnErrorMessage(message);
    ToastService().showToast(message);
  }

  Future<void> _handleStartedOperationFailure(
    String message,
    CoreRunMode mode,
    int generation,
  ) async {
    if (await _abortStart(mode, generation)) {
      await _handleStartFailure(message, generation);
      return;
    }
    await _restoreRunningStateAfterStopFailure(message, generation);
    ToastService().showToast(message);
  }

  Future<bool> _abortStart(CoreRunMode mode, int generation) async {
    if (!_commands.isCurrent(generation)) {
      return false;
    }
    try {
      NativeVpnCommandResult result;
      if (mode == CoreRunMode.proxy) {
        result = await _stopProxyCore();
      } else {
        result = await AppHostApi().stopVpn();
        _applyNativeCommandResult(result);
      }
      if (result.state == NativeVpnCommandState.failed) {
        return false;
      }
      var disconnected = await _waitForVpnStatus(
        {VpnStatus.disconnected},
        generation,
        timeoutSeconds: 5,
      );
      if (!disconnected) {
        await _refreshVpnStatus(generation);
        disconnected = await _waitForVpnStatus(
          {VpnStatus.disconnected},
          generation,
          timeoutSeconds: 2,
        );
      }
      if (!disconnected) {
        return false;
      }
      await _drainStatusUpdates(generation);
      _connectivity.stop();
      await _clearStartSnapshot();
      return true;
    } catch (error, stackTrace) {
      ygLogger('abort VPN start failed: $error\n$stackTrace');
      return false;
    }
  }

  Future<void> _restoreRunningStateAfterStopFailure(
    String message,
    int generation,
  ) async {
    if (!_commands.isCurrent(generation)) {
      return;
    }
    _vpnRunning = true;
    _lastVpnStatus = VpnStatus.connected;
    final eventBus = AppEventBus.instance;
    final currentRunningId = eventBus.state.runningId;
    final runningId = _runningRoutingMode == CoreRoutingMode.direct
        ? DBConstants.defaultId
        : currentRunningId != DBConstants.defaultId
        ? currentRunningId
        : _pendingConfigId != DBConstants.defaultId
        ? _pendingConfigId
        : _lastConfigId;
    _pendingConfigId = DBConstants.defaultId;
    eventBus.updatePendingConfigId(DBConstants.defaultId);
    eventBus.updateVpnActionState(VpnActionState.connected);
    eventBus.updateVpnErrorMessage(message);
    await _updateRunningId(runningId, generation);
    unawaited(_startConnectivity());
  }

  Future<void> _clearStartSnapshot() async {
    try {
      await FileTool.deleteFileIfExists(VpnConstants.startPath);
    } catch (error, stackTrace) {
      ygLogger('clear VPN runtime snapshot failed: $error\n$stackTrace');
    }
  }

  Future<void> _drainStatusUpdates(int generation) async {
    await _statusTail;
    if (!_commands.isCurrent(generation)) {
      throw StateError('VPN operation was superseded');
    }
  }

  Future<bool> _waitForVpnStatus(
    Set<VpnStatus> statuses,
    int generation, {
    int timeoutSeconds = 15,
  }) async {
    if (!_commands.isCurrent(generation)) {
      return false;
    }
    if (statuses.contains(_lastVpnStatus)) {
      return true;
    }
    try {
      await AppFlutterApi().vpnStatusController.stream
          .firstWhere(
            (status) =>
                _commands.isCurrent(generation) && statuses.contains(status),
          )
          .timeout(Duration(seconds: timeoutSeconds));
      return _commands.isCurrent(generation);
    } catch (_) {
      return _commands.isCurrent(generation) &&
          statuses.contains(_lastVpnStatus);
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

  Future<NativeVpnCommandResult> _realStartXray(
    CoreConfigData? config,
    CoreRunMode mode, {
    required void Function() onStartInvoked,
  }) async {
    if (config != null) {
      await _updateLastConfigId(config.id);
    }
    await PreferencesKey().saveVpnStartTimestamp();

    final runtime = await _runtimeConfig.prepare(config, mode: mode);
    _pendingRunMode = runtime.mode;
    _pendingRoutingMode = runtime.routingMode;
    switch (runtime.mode) {
      case CoreRunMode.tun:
        return _makeVpnRequestAndStart(
          runtime.coreInvokeText,
          runtime.ports,
          runtime.tunSettings,
          onStartInvoked,
        );
      case CoreRunMode.proxy:
        return _makeProxyRequestAndStart(
          runtime.coreInvokeText,
          runtime.ports,
          onStartInvoked,
        );
    }
  }

  Future<NativeVpnCommandResult> _makeProxyRequestAndStart(
    String coreInvokeText,
    XrayPorts port,
    void Function() onStartInvoked,
  ) async {
    final request = StartVpnRequest(
      null,
      port.pingPort,
      port.pingAuth,
      port.metricsPort,
      coreInvokeText,
    );
    await request.writeToStartFile();

    await _queueVpnStatus(VpnStatus.connecting);
    onStartInvoked();
    final error = await AppHostApi().runXray(coreInvokeText);
    if (error.isNotEmpty) {
      await _queueVpnStatus(VpnStatus.disconnected);
      return _commandFailed(error);
    }
    await _queueVpnStatus(VpnStatus.connected);
    return _commandSuccess();
  }

  Future<NativeVpnCommandResult> _makeVpnRequestAndStart(
    String coreInvokeText,
    XrayPorts port,
    TunSettingsState tunSettingsState,
    void Function() onStartInvoked,
  ) async {
    final request = StartVpnRequest(
      tunSettingsState.tunJson,
      port.pingPort,
      port.pingAuth,
      port.metricsPort,
      coreInvokeText,
    );
    await request.writeToStartFile();

    onStartInvoked();
    final result = await AppHostApi().startVpn();
    _applyNativeCommandResult(result);
    return result;
  }

  Future<void> retryConnectivityTest() {
    return _connectivity.retry();
  }

  bool get _isCoreActive =>
      _vpnRunning ||
      _lastVpnStatus == VpnStatus.connected ||
      _lastVpnStatus == VpnStatus.connecting ||
      AppEventBus.instance.state.runningId != DBConstants.defaultId;
}
