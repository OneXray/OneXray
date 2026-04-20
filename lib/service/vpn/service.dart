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
import 'package:onexray/service/xray/setting/state_reader.dart';
import 'package:onexray/service/xray/setting/state_writer.dart';

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

    await _listenVpnStatus();

    await AppHostApi().checkVpnPermission();
  }

  void dispose() {
    _vpnStatusSubscription.cancel();
  }

  late StreamSubscription<VpnStatus> _vpnStatusSubscription;

  Future<void> _listenVpnStatus() async {
    ygLogger("_listenVpnStatus");
    _vpnStatusSubscription = AppFlutterApi().vpnStatusController.stream.listen(
      _vpnStatusChanged,
    );
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
        await _realStartXray(outbound);
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
    outboundState.readFromDbData(config);
    settingState.outbounds.outbounds.add(outboundState);

    await settingState.fixSetting(tunSettingState, port);
    final xrayJson = settingState.xrayJson;
    final configPath = await xrayJson.writeConfig(runDir);
    return configPath;
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
    String? mphCachePath;
    if (AppPlatform.isIOS) {
      final error = await AppHostApi().buildMphCache(
        VpnConstants.datDir,
        VpnConstants.mphCachePath,
        configPath,
      );
      if (error.isNotEmpty) {
        ygLogger("Build mph cache error: $error");
        return null;
      }
      mphCachePath = VpnConstants.mphCachePath;
    }

    final xrayParam = RunXrayRequest(
      VpnConstants.datDir,
      mphCachePath,
      configPath,
    ).toJson();

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
    final text = duration.pretty(locale: locale);
    final eventBus = AppEventBus.instance;
    eventBus.updateLocationDuration(text);
  }
}
