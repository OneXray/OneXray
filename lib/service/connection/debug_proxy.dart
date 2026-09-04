import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/xray/runtime_inbounds.dart';

/// Developer-only host adaptation. Never persisted or exposed as a VPN mode.
/// The connection coordinator serializes start/stop; this emits no VPN events.
class IOSDebugProxy {
  static final IOSDebugProxy _instance = IOSDebugProxy._();
  factory IOSDebugProxy() => _instance;
  IOSDebugProxy._();

  bool _enabled = false;
  bool _running = false;

  bool get supported =>
      supportsEnvironment(debugMode: kDebugMode, isIOS: AppPlatform.isIOS);
  bool get enabled => supported && _enabled;
  set enabled(bool value) => _enabled = supported && value;

  /// Ownership of the in-process Debug core, not the system VPN's state.
  bool get running => supported && _running;

  @visibleForTesting
  static bool supportsEnvironment({
    required bool debugMode,
    required bool isIOS,
  }) => debugMode && isIOS;

  Future<NativeVpnCommandResult> start(ConnectionRuntime runtime) async {
    if (!enabled) return _failed('debugProxyUnavailable');
    if (_running) return _failed('debugProxyAlreadyRunning');
    try {
      final error = await AppHostApi().runXray(buildInvoke(runtime));
      if (error.isNotEmpty) return _failed(error);
      _running = true;
      return NativeVpnCommandResult(state: NativeVpnCommandState.success);
    } catch (_) {
      return _failed('debugProxyStartFailed');
    }
  }

  Future<NativeVpnCommandResult> stop() async {
    if (!supported) return _failed('debugProxyUnavailable');
    // Disabling the switch must not strand a core which we already started.
    if (!_running) {
      return NativeVpnCommandResult(state: NativeVpnCommandState.success);
    }
    try {
      final error = await AppHostApi().stopXray();
      if (error.isNotEmpty) return _failed(error);
      _running = false;
      return NativeVpnCommandResult(state: NativeVpnCommandState.success);
    } catch (_) {
      return _failed('debugProxyStopFailed');
    }
  }

  static NativeVpnCommandResult _failed(String message) =>
      NativeVpnCommandResult(
        state: NativeVpnCommandState.failed,
        message: message,
      );

  /// Converts a copy of the prepared host invocation; the input stays unchanged.
  /// Keeping tunIn's tag preserves routing, metrics and the managed session.
  static String buildInvoke(ConnectionRuntime runtime) {
    final request = runtime.request;
    final port = int.tryParse(request.socksPort ?? '');
    if (runtime.platform != ConnectionPlatform.ios ||
        port == null ||
        port < 1 ||
        port > 65535 ||
        port == int.tryParse(request.metricsPort ?? '') ||
        request.coreInvokeText == null) {
      throw const FormatException('Invalid iOS Debug proxy runtime');
    }
    final config = LibXrayRunConfig.fromInvokeText(request.coreInvokeText!);
    if (config.invoke.method != LibXrayMethod.runXray ||
        config.request.xrayJson == null ||
        config.request.runtime?.inboundTag != 'tunIn') {
      throw const FormatException('Invalid managed Debug invocation');
    }
    final xray = jsonDecode(config.request.xrayJson!);
    if (xray is! Map<String, dynamic> || xray['inbounds'] is! List) {
      throw const FormatException('Missing managed Debug inbound');
    }
    final inbounds = xray['inbounds'] as List;
    final indices = [
      for (var i = 0; i < inbounds.length; i++)
        if (inbounds[i] is Map && inbounds[i]['tag'] == 'tunIn') i,
    ];
    if (indices.length != 1) {
      throw const FormatException('Invalid managed Debug inbound');
    }
    inbounds[indices.single] = createSocksInboundMap('$port');
    config.invoke.payload!['xrayJson'] = jsonEncode(xray);
    return jsonEncode(config.invoke.toJson());
  }
}
