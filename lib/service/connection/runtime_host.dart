// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/tun2socks.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_writer.dart';
import 'package:onexray/service/connection/debug_proxy.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/connection/traffic_accounting.dart';
import 'package:onexray/service/xray/metrics/model.dart';
import 'package:path/path.dart' as p;

export 'traffic_accounting.dart' show RuntimeSnapshot;

class HostConnection {
  final VpnStatus status;
  final ConnectionRuntime? runtime;
  final RuntimeSnapshot? traffic;
  const HostConnection(this.status, {this.runtime, this.traffic});
  bool get connected => status == VpnStatus.connected;
}

class ConnectionHostException implements Exception {
  final String reason;
  final PlatformPermissionResult? permission;
  const ConnectionHostException(this.reason, {this.permission});
  @override
  String toString() => reason;
}

/// Native status owns VPN state. Xray metrics supplies live counters; libXray
/// periodically exposes the same current session through authenticated HTTP.
class ConnectionRuntimeHost {
  final AppHostApi _host = AppHostApi();
  final String? _runDirectory;
  final RuntimeSnapshotReader? _readSnapshot;
  final Future<XrayMetricsVars> Function(int port)? _metrics;
  final Future<VpnStatus> Function()? _readStatus;
  final Future<NativeVpnCommandResult> Function(ConnectionRuntime runtime)?
  _startVpn;
  final Future<NativeVpnCommandResult> Function()? _stopVpn;
  final Duration startTimeout;
  final Duration stopTimeout;
  final Duration pollInterval;
  ConnectionRuntime? _runtime;
  bool _runtimeOnline = true;

  ConnectionRuntimeHost({
    String? runDirectory,
    RuntimeSnapshotReader? readRuntimeSnapshot,
    Future<XrayMetricsVars> Function(int port)? readMetrics,
    Future<VpnStatus> Function()? readStatus,
    Future<NativeVpnCommandResult> Function(ConnectionRuntime runtime)?
    startVpn,
    Future<NativeVpnCommandResult> Function()? stopVpn,
    this.startTimeout = const Duration(seconds: 30),
    this.stopTimeout = const Duration(seconds: 15),
    this.pollInterval = const Duration(milliseconds: 200),
  }) : _runDirectory = runDirectory,
       _readSnapshot = readRuntimeSnapshot,
       _readStatus = readStatus,
       _startVpn = startVpn,
       _stopVpn = stopVpn,
       _metrics = readMetrics;

  String get _directory => _runDirectory ?? VpnConstants.runDir;
  late final _accounting = TrafficAccounting(
    path: p.join(_directory, 'traffic-totals.json'),
    readRuntimeSnapshot: _state,
  );

  Future<VpnStatus> _status() async {
    final readStatus = _readStatus;
    if (readStatus != null) return readStatus();
    if (IOSDebugProxy().running) return VpnStatus.connected;
    final event = AppFlutterApi().vpnStatusController.stream.first.timeout(
      const Duration(seconds: 5),
    );
    final result = await _host.readVpnStatus();
    if (result.state != NativeVpnCommandState.success) {
      unawaited(event.then<void>((_) {}, onError: (Object _) {}));
      throw ConnectionHostException(
        'nativeStatusFailed',
        permission: result.permission,
      );
    }
    return event;
  }

  Future<RuntimeSnapshot?> _state() async {
    final reader = _readSnapshot;
    if (reader != null) return reader();
    if (!_runtimeOnline) {
      throw const ConnectionHostException('runtimeStateUnavailable');
    }
    final candidates = <ConnectionRuntime>[?_runtime, ?await readRuntime()];
    final tried = <String>{};
    for (final runtime in candidates) {
      if (!tried.add(runtime.identity)) continue;
      try {
        final snapshot = await _stateFor(runtime);
        _runtime = runtime;
        return snapshot;
      } on Exception {
        // A previous endpoint may have closed during a connection switch.
      }
    }
    throw const ConnectionHostException('runtimeStateUnavailable');
  }

  Future<RuntimeSnapshot> _stateFor(ConnectionRuntime runtime) async {
    final reader = _readSnapshot;
    if (reader != null) {
      final snapshot = await reader();
      if (snapshot == null) {
        throw const ConnectionHostException('runtimeStateUnavailable');
      }
      return snapshot;
    }
    final managed = runtime.managed;
    final address = RegExp(r'^127\.0\.0\.1:([0-9]{1,5})$')
        .firstMatch(managed.listen ?? '');
    final port = int.tryParse(address?.group(1) ?? '');
    if (port == null ||
        port < 1 ||
        port > 65535 ||
        !_safeToken.hasMatch(managed.token ?? '')) {
      throw const ConnectionHostException('runtimeStateUnavailable');
    }
    return RuntimeSnapshot.fromJson(
      await _httpJson(
        Uri(scheme: 'http', host: '127.0.0.1', port: port, path: '/runtime'),
        token: managed.token,
        maximumBytes: 1024 * 1024,
      ),
    );
  }

  static final _safeToken = RegExp(r'^[a-f0-9]{32}$');

  static Map<String, dynamic> _jsonObject(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid runtime state');
    }
    return json;
  }

  Future<ConnectionRuntime?> readRuntime() async {
    try {
      final file = File(p.join(_directory, 'start.json'));
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file ||
          await file.length() > 16 * 1024 * 1024) {
        return null;
      }
      return ConnectionRuntime.fromRequest(
        StartVpnRequest.fromJson(_jsonObject(await file.readAsString())),
      );
    } on Exception {
      return null;
    } on ArgumentError {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<RuntimeSnapshot?> readSavedTraffic() => _accounting.read();

  Future<RuntimeSnapshot?> resetTraffic([ConnectionRuntime? runtime]) async {
    if (runtime != null) {
      try {
        await query(runtime);
      } on Exception {
        // An unavailable metrics endpoint must not prevent an App-only reset.
      }
    }
    return _accounting.read(reset: true);
  }

  Future<XrayMetricsVars> _readMetrics(int port) async {
    final reader = _metrics;
    if (reader != null) return reader(port);
    try {
      return XrayMetricsVars.fromJson(
        await _httpJson(
          Uri(
            scheme: 'http',
            host: '127.0.0.1',
            port: port,
            path: '/debug/vars',
          ),
        ),
      );
    } on TypeError {
      throw const FormatException('Invalid metrics counters');
    }
  }

  static Future<Map<String, dynamic>> _httpJson(
    Uri uri, {
    String? token,
    int maximumBytes = 1048576,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw const ConnectionHostException('runtimeQueryFailed');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 3))) {
        bytes.addAll(chunk);
        if (bytes.length > maximumBytes) {
          throw const FormatException('Invalid runtime response size');
        }
      }
      return _jsonObject(utf8.decode(bytes));
    } finally {
      client.close(force: true);
    }
  }

  Future<RuntimeSnapshot> query(ConnectionRuntime runtime) async {
    _runtime = runtime;
    _runtimeOnline = true;
    final before = await _stateFor(runtime);
    if (before.endedAtMs != 0) {
      throw const ConnectionHostException('runtimeSessionChanged');
    }
    final port = int.tryParse(runtime.request.metricsPort ?? '');
    if (port == null || port < 1 || port > 65535) {
      throw const ConnectionHostException('runtimeMetricsUnavailable');
    }
    final counters = (await _readMetrics(port)).tunIn;
    final uplink = counters?.uplink;
    final downlink = counters?.downlink;
    if (uplink == null || downlink == null || uplink < 0 || downlink < 0) {
      throw const ConnectionHostException('runtimeMetricsUnavailable');
    }
    final after = await _stateFor(runtime);
    if (after.sessionId != before.sessionId || after.endedAtMs != 0) {
      throw const ConnectionHostException('runtimeSessionChanged');
    }
    return (await _accounting.read(
      live: after.withCounters(
        uplink: uplink,
        downlink: downlink,
        sampledAtMs: DateTime.now().millisecondsSinceEpoch,
        available: true,
        error: '',
      ),
    ))!;
  }

  Future<HostConnection> inspect(
    Iterable<ConnectionRuntime> knownRuntimes, {
    VpnStatus? observedStatus,
    bool readMetrics = false,
  }) async {
    final status = observedStatus ?? await _status();
    _runtimeOnline = status != VpnStatus.disconnected;
    RuntimeSnapshot? saved;
    try {
      saved = await readSavedTraffic();
    } on Exception {
      // Native status remains authoritative when counters are unavailable.
    }
    if (status == VpnStatus.disconnected) {
      return HostConnection(status, traffic: saved);
    }

    final candidates = <ConnectionRuntime>[
      ...knownRuntimes,
      ?await readRuntime(),
    ];
    ConnectionRuntime? runtime;
    final tried = <String>{};
    for (final candidate in candidates) {
      if (!tried.add(candidate.identity)) continue;
      try {
        await _stateFor(candidate);
        runtime = candidate;
        _runtime = candidate;
        break;
      } on Exception {
        // Keep trying the active start request after an in-flight switch.
      }
    }
    if (runtime != null && readMetrics) {
      try {
        return HostConnection(
          status,
          runtime: runtime,
          traffic: await query(runtime),
        );
      } on Exception {
        // A saved counter is not a successful live sample.
      }
    }
    return HostConnection(
      status,
      runtime: runtime,
      traffic: saved?.withCounters(
        uplink: saved.uplink,
        downlink: saved.downlink,
        sampledAtMs: saved.sampledAtMs,
        available: false,
        error: readMetrics ? 'runtimeMetricsUnavailable' : '',
      ),
    );
  }

  Future<NativeVpnCommandResult> _start(ConnectionRuntime runtime) async {
    final startVpn = _startVpn;
    if (startVpn != null) return startVpn(runtime);
    if (IOSDebugProxy().enabled) return IOSDebugProxy().start(runtime);
    await runtime.request.writeToStartFile();
    final policy = runtime.configuration.policy;
    final windows = runtime.platform == ConnectionPlatform.windows;
    return _host.startVpn(
      windowsConfigYaml: windows
          ? buildWindowsTun2SocksConfig(
              runtime.request.socksPort!,
              enableIPv6: policy.ipv6Enabled,
            )
          : null,
      windowsNetworkSettings: windows
          ? const WindowsVpnNetworkSettings(
              ipv4Address: PlatformPolicy.tunIpv4Address,
              ipv6Address: PlatformPolicy.tunIpv6Address,
              dnsIpv4Address: PlatformPolicy.dnsIpv4Address,
              dnsIpv6Address: PlatformPolicy.dnsIpv6Address,
            )
          : null,
      windowsPolicy: windows
          ? policy.toWindowsPolicy()
          : const WindowsVpnPolicy(
              alwaysOn: false,
              allowLocalNetwork: true,
              excludedCidrs: [],
            ),
    );
  }

  Future<HostConnection> start(ConnectionRuntime runtime) async {
    _runtime = runtime;
    _runtimeOnline = true;
    final requestedAt = DateTime.now().millisecondsSinceEpoch;
    final result = await _start(runtime);
    if (result.state != NativeVpnCommandState.success) {
      throw ConnectionHostException(
        result.state == NativeVpnCommandState.waitingForPlatformPermission
            ? 'permissionRequired'
            : 'startFailed',
        permission: result.permission,
      );
    }
    final deadline = DateTime.now().add(startTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final current = await inspect([runtime], readMetrics: true);
      if (current.connected &&
          current.runtime?.identity == runtime.identity &&
          current.traffic?.available == true &&
          current.traffic!.startedAtMs >= requestedAt) {
        return current;
      }
      await Future<void>.delayed(pollInterval);
    }
    throw const ConnectionHostException('startTimeout');
  }

  Future<HostConnection> stop() async {
    final result =
        await (_stopVpn?.call() ??
            (IOSDebugProxy().running
                ? IOSDebugProxy().stop()
                : _host.stopVpn()));
    if (result.state != NativeVpnCommandState.success) {
      throw const ConnectionHostException('stopFailed');
    }
    final deadline = DateTime.now().add(stopTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final status = await _status();
      if (status == VpnStatus.disconnected) {
        _runtimeOnline = false;
        RuntimeSnapshot? saved;
        try {
          saved = await readSavedTraffic();
        } on Exception {
          // Native shutdown does not depend on traffic persistence.
        }
        return HostConnection(status, traffic: saved);
      }
      await Future<void>.delayed(pollInterval);
    }
    throw const ConnectionHostException('stopTimeout');
  }
}
