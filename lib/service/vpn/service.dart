import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:duration/duration.dart';
import 'package:duration/locale.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/standard.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/menu/tray/service.dart';
import 'package:onexray/service/notification/service.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/pigeon/model_writer.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/tun_setting/state.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/json_writer.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/raw/fix.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/setting/state_reader.dart';
import 'package:onexray/service/xray/setting/state_writer.dart';

class _VpnStartException implements Exception {
  final String message;

  _VpnStartException(this.message);
}

final class VpnService {
  static final VpnService _singleton = VpnService._internal();

  factory VpnService() => _singleton;

  VpnService._internal();

  //=================================
  var _lastConfigId = DBConstants.defaultId;
  var _nextStartId = DBConstants.defaultId;
  var _vpnRunning = false;

  bool get vpnRunning => _vpnRunning;

  Future<void> asyncInit() async {
    final eventBus = AppEventBus.instance;
    final savedRunningId = await PreferencesKey().readRunningConfigId();
    eventBus.updateRunningId(savedRunningId);

    _lastConfigId = await PreferencesKey().readLastConfigId();

    _listenVpnStatus();
  }

  void dispose() {
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
    await AppHostApi().readVpnStatus();
  }

  Future<void> _vpnStatusChanged(VpnStatus status) async {
    final eventBus = AppEventBus.instance;
    switch (status) {
      case VpnStatus.disconnecting:
        eventBus.updateVpnLoading(true);
        break;
      case VpnStatus.disconnected:
        _vpnRunning = false;
        await _tryStartVpn();
        await TrayService().refreshTrayManager();
        _stopDurationTimer();
        break;
      case VpnStatus.connecting:
        eventBus.updateVpnLoading(true);
        await _updateRunningId(_lastConfigId);
        break;
      case VpnStatus.connected:
        _vpnRunning = true;
        eventBus.updateVpnLoading(false);
        await _updateRunningId(_lastConfigId);
        await TrayService().refreshTrayManager();
        await _startDurationTimer();
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

  Future<void> restartCurrentVpn() async {
    final eventBus = AppEventBus.instance;
    final configId = eventBus.state.runningId;
    await stopDefaultVpn();
    _nextStartId = configId;
    await _tryStartVpn();
  }

  Future<void> startDefaultVpn() async {
    final eventBus = AppEventBus.instance;
    if (eventBus.state.runningId != DBConstants.defaultId) {
      return;
    }

    final permission = await VpnService().checkPermission();
    if (!permission) {
      await NotificationService().pushNotification(
        appLocalizationsNoContext().homePageOpenSettings,
      );
      return;
    }

    final db = AppDatabase();
    if (_lastConfigId == DBConstants.defaultId) {
      await _startRandomVpn();
    } else {
      final config = await db.coreConfigDao.searchRow(_lastConfigId);
      if (config == null) {
        await _startRandomVpn();
      } else {
        await startVpn(config.id);
      }
    }
  }

  Future<void> _startRandomVpn() async {
    final db = AppDatabase();
    final config = await db.coreConfigDao.randomConfig();
    if (config == null) {
      await NotificationService().pushNotification(
        appLocalizationsNoContext().vpnNoConfig,
      );
    } else {
      await startVpn(config.id);
    }
  }

  Future<void> stopDefaultVpn() async {
    await startVpn(DBConstants.defaultId);
  }

  Future<void> startVpn(int configId) async {
    final eventBus = AppEventBus.instance;
    if (configId != eventBus.state.runningId) {
      _nextStartId = configId;
    } else {
      _nextStartId = DBConstants.defaultId;
    }
    await AppHostApi().stopVpn();
  }

  Future<bool> checkPermission() async {
    if (AppPlatform.isAndroid) {
      final granted = await AppHostApi().checkVpnPermission();
      return granted;
    }
    return true;
  }

  Future<void> _tryStartVpn() async {
    final eventBus = AppEventBus.instance;
    if (_nextStartId != DBConstants.defaultId) {
      final rowId = _nextStartId;

      _nextStartId = DBConstants.defaultId;
      eventBus.updateVpnLoading(true);

      final db = AppDatabase();
      final outbound = await db.coreConfigDao.searchRow(rowId);
      if (outbound != null) {
        try {
          await _realStartXray(outbound);
        } on _VpnStartException catch (e) {
          await _updateRunningId(DBConstants.defaultId);
          eventBus.updateVpnLoading(false);
          ToastService().showToast(e.message);
        }
      } else {
        await _updateRunningId(DBConstants.defaultId);
        eventBus.updateVpnLoading(false);
        ToastService().showToast(
          appLocalizationsNoContext().vpnSelectOneConfig,
        );
      }
    } else {
      await _updateRunningId(DBConstants.defaultId);
      eventBus.updateVpnLoading(false);
    }
  }

  Future<void> _realStartXray(CoreConfigData config) async {
    _updateLastConfigId(config.id);
    _updateRunningId(config.id);
    await PreferencesKey().saveVpnStartTimestamp();

    final runDir = VpnConstants.runDir;
    await FileTool.checkDir(runDir);

    final ports = await XrayPorts.getPorts();
    if (ports == null) {
      return;
    }

    final db = AppDatabase();
    final outbound = await db.coreConfigDao.searchRow(config.id);
    if (outbound == null) {
      return;
    }

    final coreConfigType = CoreConfigType.fromString(config.type);
    if (coreConfigType == null) {
      return;
    }
    final tunSettingState = TunSettingState();
    await tunSettingState.readFromPreferences();
    var configPath = "";
    switch (coreConfigType) {
      case CoreConfigType.outbound:
        configPath = await _writeXrayUIConfig(
          config,
          tunSettingState,
          ports,
          runDir,
        );
        break;
      case CoreConfigType.raw:
        configPath = await _writeXrayRawConfig(
          coreConfigType,
          config,
          tunSettingState,
          ports,
          runDir,
        );
        break;
      default:
        return;
    }

    await _clearXrayLog();

    final coreBase64Text = await _makeRunXrayRequest(configPath);
    if (coreBase64Text == null) {
      return;
    }

    await _makeVpnRequestAndStart(
      coreBase64Text,
      runDir,
      ports,
      tunSettingState,
    );
  }

  Future<void> _clearXrayLog() async {
    await File(XrayStateConstants.accessLogPath).writeAsString("");
    await File(XrayStateConstants.errorLogPath).writeAsString("");
  }

  Future<String> _writeXrayUIConfig(
    CoreConfigData config,
    TunSettingState tunSettingState,
    XrayPorts port,
    String runDir,
  ) async {
    final settingState = await XraySettingStateReader.loadFromDb();

    final outboundState = OutboundState();
    var outboundValid = false;
    try {
      outboundValid = outboundState.readFromDbData(config);
    } catch (_) {
      outboundValid = false;
    }
    if (!outboundValid) {
      throw _VpnStartException(appLocalizationsNoContext().vpnOutboundInvalid);
    }
    await _applyChainProxy(settingState, outboundState, config);
    settingState.outbounds.outbounds.add(outboundState);

    await settingState.fixSetting(tunSettingState, port);
    final xrayJson = settingState.xrayJson;
    final configPath = await xrayJson.writeConfig(runDir);
    return configPath;
  }

  Future<void> _applyChainProxy(
    XraySettingState settingState,
    OutboundState outboundState,
    CoreConfigData config,
  ) async {
    outboundState.tag = RoutingOutboundTag.proxy.name;

    final simpleChainProxyId = await _simpleChainProxyOutboundId();
    if (simpleChainProxyId != null) {
      if (simpleChainProxyId == config.id) {
        throw _VpnStartException(
          appLocalizationsNoContext().vpnChainProxySameAsOutbound,
        );
      }
      settingState.outbounds.chainProxy = await _loadChainProxy(
        simpleChainProxyId,
      );
    }

    final chainProxy = settingState.outbounds.chainProxy;
    if (chainProxy != null) {
      chainProxy.tag = RoutingOutboundTag.chainProxy.name;
      chainProxy.dialerProxy = "";
      outboundState.dialerProxy = RoutingOutboundTag.chainProxy.name;
    }
  }

  Future<int?> _simpleChainProxyOutboundId() async {
    final settingId = await PreferencesKey().readXraySettingId();
    if (settingId != XraySettingSimple.simpleId) {
      return null;
    }
    final simple = XraySettingSimple();
    await simple.readFromPreferences();
    return simple.chainProxyOutboundId;
  }

  Future<OutboundState> _loadChainProxy(int id) async {
    final db = AppDatabase();
    final row = await db.coreConfigDao.searchRow(id);
    if (row == null) {
      throw _VpnStartException(
        appLocalizationsNoContext().vpnChainProxyMissing,
      );
    }
    if (CoreConfigType.fromString(row.type) != CoreConfigType.outbound) {
      throw _VpnStartException(
        appLocalizationsNoContext().vpnChainProxyInvalid,
      );
    }
    final chainProxy = OutboundState();
    var valid = false;
    try {
      valid = chainProxy.readFromDbData(row);
    } catch (_) {
      valid = false;
    }
    if (!valid) {
      throw _VpnStartException(
        appLocalizationsNoContext().vpnChainProxyInvalid,
      );
    }
    chainProxy.name = row.name;
    chainProxy.tag = RoutingOutboundTag.chainProxy.name;
    chainProxy.dialerProxy = "";
    return chainProxy;
  }

  Future<String> _writeXrayRawConfig(
    CoreConfigType coreConfigType,
    CoreConfigData config,
    TunSettingState tunSettingState,
    XrayPorts port,
    String runDir,
  ) async {
    final bytes = base64Decode(config.data!);
    final rawText = utf8.decode(bytes);
    final jsonMap = JsonTool.decoder.convert(rawText);
    await XrayRawFix.fixConfig(jsonMap, tunSettingState, port);
    final configText = JsonTool.encoderForFile.convert(jsonMap);
    final configPath = XrayStateConstants.configFilePath;
    final file = File(configPath);
    await file.writeAsString(configText);
    return configPath;
  }

  Future<void> _makeVpnRequestAndStart(
    String coreBase64Text,
    String runDir,
    XrayPorts port,
    TunSettingState tunSettingState,
  ) async {
    final tunPriority = int.tryParse(tunSettingState.tunPriority);
    if (tunPriority == null) {
      return;
    }

    final request = StartVpnRequest(
      tunSettingState.tunJson,
      port.pingPort,
      coreBase64Text,
    );
    await request.writeToStartFile();

    await AppHostApi().startVpn();
  }

  Future<String?> _makeRunXrayRequest(String configPath) async {
    final xrayParam = RunXrayRequest(VpnConstants.datDir, configPath).toJson();

    final coreBase64Text = JsonTool.encodeJsonToBase64(xrayParam);
    return coreBase64Text;
  }

  Future<void> _connectivityTest() async {
    final request = await StartVpnRequestReader.readFromStartFile();
    if (request.pingPort == null) {
      return;
    }
    // delay three seconds
    await Future.delayed(Duration(seconds: 3));

    final pingState = PingState();
    await pingState.readFromPreferences();
    final location = await NetClient().connectivityTest(
      request.pingPort!,
      pingState.realUrl,
    );
    final eventBus = AppEventBus.instance;
    eventBus.updateLocation(location);
  }

  Timer? _timer;
  var _startTime = DateTime.now();

  Future<void> _startDurationTimer() async {
    _stopDurationTimer();
    _startTime = await PreferencesKey().readVpnStartTimestamp();
    _timer = Timer.periodic(Duration(seconds: 1), (_) => _updateDuration());
    await _connectivityTest();
  }

  void _stopDurationTimer() {
    _timer?.cancel();
    _timer = null;
    final eventBus = AppEventBus.instance;
    eventBus.updateLocation(GeoLocationStandard.standard);
  }

  void _updateDuration() {
    final now = DateTime.now();
    final duration = now.difference(_startTime);
    final languageCode =
        AppEventBus.instance.state.languageCode.locale.languageCode;
    final locale =
        DurationLocale.fromLanguageCode(languageCode) ??
        EnglishDurationLocale();
    final text = _formatDuration(duration, locale);
    final eventBus = AppEventBus.instance;
    eventBus.updateLocationDuration(text);
  }

  String _formatDuration(Duration duration, DurationLocale locale) {
    if (duration.inHours >= 1) {
      return duration.pretty(
        locale: locale,
        tersity: DurationTersity.hour,
        upperTersity: DurationTersity.hour,
      );
    }
    if (duration.inMinutes >= 1) {
      return duration.pretty(
        locale: locale,
        tersity: DurationTersity.minute,
        upperTersity: DurationTersity.minute,
      );
    }
    return duration.pretty(
      locale: locale,
      tersity: DurationTersity.second,
      upperTersity: DurationTersity.second,
    );
  }
}
