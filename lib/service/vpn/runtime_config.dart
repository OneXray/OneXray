import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/tun_settings/state_validator.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_reader.dart';
import 'package:onexray/service/xray/multi_node_outbound/state_validator.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/state_reader.dart';
import 'package:onexray/service/xray/profile/state_validator.dart';
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
    final tunSettingsValidation = await tunSettings.validate();
    if (!tunSettingsValidation.item1) {
      throw XrayRuntimeConfigException(tunSettingsValidation.item2);
    }
    final profileMap = await loadSelectedProfileMap(tunSettings);
    final profileValidation = validateProfileFields(profileMap);
    if (!profileValidation.item1) {
      throw XrayRuntimeConfigException(profileValidation.item2);
    }
    final materializeMultiNodeOutbound =
        config != null &&
        CoreConfigType.fromString(config.type) ==
            CoreConfigType.multiNodeOutbound;
    final excludedPorts = _runtimeListeningPorts(
      profileMap,
      includeMetrics: !tunSettings.metricsEnabled,
    );
    final ports = await XrayPorts.getPorts(excludedPorts: excludedPorts);
    if (ports == null) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnLocalPortFailed,
      );
    }

    final configPath =
        routingMode == CoreRoutingMode.direct && !materializeMultiNodeOutbound
        ? await _writeDirect(profileMap, mode, tunSettings, ports)
        : await _writeSelectedConfig(
            config,
            profileMap,
            mode,
            routingMode,
            tunSettings,
            ports,
          );

    await _clearXrayLogs();
    final invoke = LibXrayInvokeRequest(
      method: LibXrayMethod.runXray,
      payload: RunXrayRequest(await File(configPath).readAsString()).toJson(),
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
    Map<String, dynamic> profileMap,
    CoreRunMode mode,
    CoreRoutingMode routingMode,
    TunSettingsState tunSettings,
    XrayPorts ports,
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
        profileMap,
        mode,
        routingMode,
        tunSettings,
        ports,
      ),
      CoreConfigType.raw => _writeRaw(
        config,
        profileMap,
        mode,
        routingMode,
        tunSettings,
        ports,
      ),
      CoreConfigType.multiNodeOutbound => _writeMultiNodeOutbound(
        config,
        profileMap,
        mode,
        routingMode,
        tunSettings,
        ports,
      ),
      _ => throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnSelectOneConfig,
      ),
    };
  }

  Future<String> _writeOutbound(
    CoreConfigData config,
    Map<String, dynamic> profileMap,
    CoreRunMode mode,
    CoreRoutingMode routingMode,
    TunSettingsState tunSettings,
    XrayPorts ports,
  ) async {
    late final Map<String, dynamic> outbound;
    try {
      outbound = readOutboundFromDbData(config);
      requireCanonicalOutbound(outbound);
    } catch (_) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnOutboundInvalid,
      );
    }
    final runtimeMap = copyXrayConfigMap(profileMap);
    final finalOutbound = await _resolveFinalOutbound(runtimeMap, config);
    XrayRawFix.applySelectedOutbound(
      runtimeMap,
      outbound,
      finalOutbound: finalOutbound,
    );
    return _writeProfileMap(runtimeMap, mode, routingMode, tunSettings, ports);
  }

  Future<Map<String, dynamic>?> _resolveFinalOutbound(
    Map<String, dynamic> profileMap,
    CoreConfigData config,
  ) async {
    final simpleFinalOutboundId = await _simpleFinalOutboundId();
    if (simpleFinalOutboundId != null) {
      if (simpleFinalOutboundId == config.id) {
        throw XrayRuntimeConfigException(
          appLocalizationsNoContext().vpnFinalOutboundSameAsOutbound,
        );
      }
      return _loadFinalOutbound(simpleFinalOutboundId);
    }

    return _embeddedFinalOutbound(profileMap);
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

  Future<Map<String, dynamic>> _loadFinalOutbound(int id) async {
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
    late final Map<String, dynamic> outbound;
    try {
      outbound = readOutboundFromDbData(row);
      requireCanonicalOutbound(outbound);
    } catch (_) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnFinalOutboundInvalid,
      );
    }
    if (outboundString(outbound, 'name')?.isNotEmpty != true) {
      outbound['name'] = row.name;
    }
    setOutboundTag(outbound, RoutingOutboundTag.proxy.name);
    removeOutboundDialerProxy(outbound);
    return outbound;
  }

  Future<String> _writeRaw(
    CoreConfigData config,
    Map<String, dynamic> profileMap,
    CoreRunMode mode,
    CoreRoutingMode routingMode,
    TunSettingsState tunSettings,
    XrayPorts ports,
  ) async {
    final rawText = utf8.decode(base64Decode(config.data!));
    final jsonMap = JsonTool.decoder.convert(rawText);
    await XrayRawFix.fixConfig(
      jsonMap,
      profileMap,
      mode,
      tunSettings,
      ports,
      tunSettings.metricsEnabled,
      runtimePlatform: XrayRuntimePlatform.current,
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

  Future<String> _writeMultiNodeOutbound(
    CoreConfigData config,
    Map<String, dynamic> profileMap,
    CoreRunMode mode,
    CoreRoutingMode routingMode,
    TunSettingsState tunSettings,
    XrayPorts ports,
  ) async {
    late final Map<String, dynamic> multiNodeOutbound;
    try {
      multiNodeOutbound = readMultiNodeOutboundFromDbData(config);
    } catch (_) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnOutboundInvalid,
      );
    }
    final validation = validateMultiNodeOutboundFields(multiNodeOutbound);
    if (!validation.item1) {
      throw XrayRuntimeConfigException(validation.item2);
    }
    final runtimeMap = applyMultiNodeOutboundOverlay(
      profileMap,
      multiNodeOutbound,
    );
    return _writeProfileMap(runtimeMap, mode, routingMode, tunSettings, ports);
  }

  Future<String> _writeDirect(
    Map<String, dynamic> profileMap,
    CoreRunMode mode,
    TunSettingsState tunSettings,
    XrayPorts ports,
  ) async {
    return _writeProfileMap(
      copyXrayConfigMap(profileMap),
      mode,
      CoreRoutingMode.direct,
      tunSettings,
      ports,
    );
  }

  Future<String> _writeProfileMap(
    Map<String, dynamic> runtimeMap,
    CoreRunMode mode,
    CoreRoutingMode routingMode,
    TunSettingsState tunSettings,
    XrayPorts ports,
  ) async {
    await XrayRawFix.fixProfileConfig(
      runtimeMap,
      mode,
      tunSettings,
      ports,
      tunSettings.metricsEnabled,
      runtimePlatform: XrayRuntimePlatform.current,
    );
    if (!XrayRoutingModeFix.applyToRawJson(runtimeMap, routingMode)) {
      throw XrayRuntimeConfigException(
        appLocalizationsNoContext().vpnRoutingModeProxyMissing,
      );
    }
    final file = File(XrayStateConstants.configFilePath);
    await file.writeAsString(JsonTool.encoder.convert(runtimeMap));
    return file.path;
  }

  Future<void> _clearXrayLogs() async {
    await Future.wait([
      File(XrayStateConstants.accessLogPath).writeAsString(''),
      File(XrayStateConstants.errorLogPath).writeAsString(''),
    ]);
  }
}

Map<String, dynamic>? _embeddedFinalOutbound(Map<String, dynamic> profileMap) {
  final outbounds = profileMap['outbounds'];
  if (outbounds is! List<dynamic>) {
    return null;
  }
  Map<String, dynamic>? result;
  for (final outbound in outbounds.whereType<Map<String, dynamic>>()) {
    if (outboundString(outbound, 'tag') == RoutingOutboundTag.chainProxy.name) {
      requireCanonicalOutbound(outbound);
      result = copyOutboundMap(outbound);
    }
  }
  return result;
}

Set<int> _runtimeListeningPorts(
  Map<String, dynamic> config, {
  required bool includeMetrics,
}) {
  final ports = <int>{};
  final inbounds = config['inbounds'];
  if (inbounds is List<dynamic>) {
    for (final inbound in inbounds.whereType<Map>()) {
      _addPortValue(ports, inbound['port']);
    }
  }
  if (includeMetrics) {
    final metrics = config['metrics'];
    if (metrics is Map) {
      final listen = metrics['listen'];
      if (listen is String) {
        _addPort(ports, listen.substring(listen.lastIndexOf(':') + 1));
      }
    }
  }
  return ports;
}

void _addPortValue(Set<int> ports, dynamic value) {
  if (value is int) {
    _addPort(ports, '$value');
    return;
  }
  if (value is! String) {
    return;
  }
  for (final part in value.split(',')) {
    final bounds = part.trim().split('-');
    if (bounds.length == 1) {
      _addPort(ports, bounds.single);
      continue;
    }
    if (bounds.length != 2) {
      continue;
    }
    final start = int.tryParse(bounds.first.trim());
    final end = int.tryParse(bounds.last.trim());
    if (start == null || end == null || start > end) {
      continue;
    }
    final firstPort = start < 1 ? 1 : start;
    final lastPort = end > 65535 ? 65535 : end;
    for (var port = firstPort; port <= lastPort; port++) {
      ports.add(port);
    }
  }
}

void _addPort(Set<int> ports, String value) {
  final port = int.tryParse(value.trim());
  if (port != null && port > 0 && port <= 65535) {
    ports.add(port);
  }
}
