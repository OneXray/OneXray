import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_reader.dart';
import 'package:onexray/service/xray/full_config/state_validator.dart';
import 'package:onexray/service/xray/full_config/state_writer.dart';
import 'package:onexray/service/xray/json_writer.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/state.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_writer.dart';
import 'package:onexray/service/xray/raw/fix.dart';
import 'package:onexray/service/xray/routing_mode.dart';

class XrayRuntimeConfigException implements Exception {
  final String message;

  const XrayRuntimeConfigException(this.message);
}

class XrayRuntimeConfig {
  final CoreRunMode mode;
  final CoreRoutingMode routingMode;
  final TunSettingsState tunSettings;
  final XrayPorts ports;
  final String coreInvokeText;

  const XrayRuntimeConfig({
    required this.mode,
    required this.routingMode,
    required this.tunSettings,
    required this.ports,
    required this.coreInvokeText,
  });
}

final class XrayRuntimeConfigService {
  Future<XrayRuntimeConfig> prepare(
    CoreConfigData? config, {
    required CoreRunMode mode,
  }) async {
    try {
      return await _prepare(config, CoreRunModePolicy.resolve(mode));
    } on XrayRuntimeConfigException {
      rethrow;
    } catch (error, stackTrace) {
      ygLogger(
        'Xray runtime configuration preparation failed: $error\n$stackTrace',
      );
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnStartRequestFailed,
      );
    }
  }

  Future<XrayRuntimeConfig> _prepare(
    CoreConfigData? config,
    CoreRunMode mode,
  ) async {
    final routingMode = await PreferencesKey().readCoreRoutingMode();
    final runDir = VpnConstants.runDir;
    await FileTool.checkDir(runDir);

    final tunSettings = TunSettingsState();
    await tunSettings.readFromPreferences();
    final profile = await XrayProfileStateReader.loadFromDb(tunSettings);

    final ports = await XrayPorts.getPorts();
    if (ports == null) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnLocalPortFailed,
      );
    }

    final configPath = routingMode == CoreRoutingMode.direct
        ? await _writeDirect(profile, mode, tunSettings, ports, runDir)
        : await _writeSelectedConfig(
            config,
            profile,
            mode,
            routingMode,
            tunSettings,
            ports,
            runDir,
          );

    await _clearXrayLogs();
    final invoke = LibXrayInvokeRequest(
      method: LibXrayMethod.runXray,
      payload: RunXrayRequest(configPath).toJson(),
    );
    return XrayRuntimeConfig(
      mode: mode,
      routingMode: routingMode,
      tunSettings: tunSettings,
      ports: ports,
      coreInvokeText: JsonTool.encoder.convert(invoke.toJson()),
    );
  }

  Future<String> _writeSelectedConfig(
    CoreConfigData? config,
    XrayProfileState profile,
    CoreRunMode mode,
    CoreRoutingMode routingMode,
    TunSettingsState tunSettings,
    XrayPorts ports,
    String runDir,
  ) async {
    if (config == null) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnSelectOneConfig,
      );
    }
    final type = CoreConfigType.fromString(config.type);
    return switch (type) {
      CoreConfigType.outbound => _writeOutbound(
        config,
        profile,
        mode,
        routingMode,
        tunSettings,
        ports,
        runDir,
      ),
      CoreConfigType.raw => _writeRaw(
        config,
        profile,
        mode,
        routingMode,
        tunSettings,
        ports,
      ),
      CoreConfigType.full => _writeFull(
        config,
        profile,
        mode,
        routingMode,
        tunSettings,
        ports,
        runDir,
      ),
      _ => throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnSelectOneConfig,
      ),
    };
  }

  Future<String> _writeOutbound(
    CoreConfigData config,
    XrayProfileState profile,
    CoreRunMode mode,
    CoreRoutingMode routingMode,
    TunSettingsState tunSettings,
    XrayPorts ports,
    String runDir,
  ) async {
    final outbound = OutboundState();
    try {
      if (!outbound.readFromDbData(config)) {
        throw const FormatException('invalid outbound data');
      }
    } catch (_) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnOutboundInvalid,
      );
    }
    await _applyFinalOutbound(profile, outbound, config);
    profile.outbounds.outbounds.add(outbound);
    final xrayJson = await profile.fixSetting(mode, tunSettings, ports);
    return _writeTypedConfig(xrayJson, routingMode, runDir);
  }

  Future<void> _applyFinalOutbound(
    XrayProfileState profile,
    OutboundState outbound,
    CoreConfigData config,
  ) async {
    final simpleFinalOutboundId = await _simpleFinalOutboundId();
    if (simpleFinalOutboundId != null) {
      if (simpleFinalOutboundId == config.id) {
        throw XrayRuntimeConfigException(
          appLocalizationsNoContext().vpnFinalOutboundSameAsOutbound,
        );
      }
      profile.outbounds.finalOutbound = await _loadFinalOutbound(
        simpleFinalOutboundId,
      );
    }

    final finalOutbound = profile.outbounds.finalOutbound;
    if (finalOutbound == null) {
      outbound.tag = RoutingOutboundTag.proxy.name;
      return;
    }

    outbound.tag = RoutingOutboundTag.chainProxy.name;
    outbound.dialerProxy = '';
    finalOutbound.tag = RoutingOutboundTag.proxy.name;
    finalOutbound.dialerProxy = RoutingOutboundTag.chainProxy.name;
    profile.outbounds.finalOutbound = null;
    profile.outbounds.outbounds.add(finalOutbound);
  }

  Future<int?> _simpleFinalOutboundId() async {
    final profileId = await PreferencesKey().readXrayProfileId();
    if (profileId != XrayProfileSimple.simpleId) {
      return null;
    }
    final simple = XrayProfileSimple();
    await simple.readFromPreferences();
    return simple.finalOutboundId;
  }

  Future<OutboundState> _loadFinalOutbound(int id) async {
    final row = await AppDatabase().coreConfigDao.searchRow(id);
    if (row == null) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnFinalOutboundMissing,
      );
    }
    if (CoreConfigType.fromString(row.type) != CoreConfigType.outbound) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnFinalOutboundInvalid,
      );
    }
    final outbound = OutboundState();
    try {
      if (!outbound.readFromDbData(row)) {
        throw const FormatException('invalid final outbound data');
      }
    } catch (_) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnFinalOutboundInvalid,
      );
    }
    outbound.name = row.name;
    outbound.tag = RoutingOutboundTag.proxy.name;
    outbound.dialerProxy = '';
    return outbound;
  }

  Future<String> _writeRaw(
    CoreConfigData config,
    XrayProfileState profile,
    CoreRunMode mode,
    CoreRoutingMode routingMode,
    TunSettingsState tunSettings,
    XrayPorts ports,
  ) async {
    final rawText = utf8.decode(base64Decode(config.data!));
    final jsonMap = JsonTool.decoder.convert(rawText);
    await XrayRawFix.fixConfig(
      jsonMap,
      profile,
      mode,
      tunSettings,
      ports,
      tunSettings.metricsEnabled,
    );
    if (routingMode == CoreRoutingMode.global &&
        !XrayRoutingModeFix.applyGlobalToRawJson(jsonMap)) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnRoutingModeProxyMissing,
      );
    }
    final file = File(XrayStateConstants.configFilePath);
    await file.writeAsString(JsonTool.encoder.convert(jsonMap));
    return file.path;
  }

  Future<String> _writeFull(
    CoreConfigData config,
    XrayProfileState profile,
    CoreRunMode mode,
    CoreRoutingMode routingMode,
    TunSettingsState tunSettings,
    XrayPorts ports,
    String runDir,
  ) async {
    final full = XrayFullConfigState();
    try {
      full.readFromDbData(config);
    } catch (_) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnOutboundInvalid,
      );
    }
    final validation = full.validateFields();
    if (!validation.item1) {
      throw XrayRuntimeConfigException(validation.item2);
    }
    full.applyToXrayProfile(profile);
    final xrayJson = await profile.fixSetting(mode, tunSettings, ports);
    return _writeTypedConfig(xrayJson, routingMode, runDir);
  }

  Future<String> _writeDirect(
    XrayProfileState profile,
    CoreRunMode mode,
    TunSettingsState tunSettings,
    XrayPorts ports,
    String runDir,
  ) async {
    final xrayJson = await profile.fixSetting(mode, tunSettings, ports);
    return _writeTypedConfig(xrayJson, CoreRoutingMode.direct, runDir);
  }

  Future<String> _writeTypedConfig(
    XrayJson xrayJson,
    CoreRoutingMode routingMode,
    String runDir,
  ) async {
    if (!XrayRoutingModeFix.applyToXrayJson(xrayJson, routingMode)) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnRoutingModeProxyMissing,
      );
    }
    return xrayJson.writeConfig(runDir);
  }

  Future<void> _clearXrayLogs() async {
    await Future.wait([
      File(XrayStateConstants.accessLogPath).writeAsString(''),
      File(XrayStateConstants.errorLogPath).writeAsString(''),
    ]);
  }
}
