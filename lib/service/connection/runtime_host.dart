import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/tun2socks.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model_writer.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/connection/traffic_accounting.dart';
import 'package:onexray/service/xray/metrics/model.dart';
import 'package:path/path.dart' as p;

export 'traffic_accounting.dart' show RuntimeSnapshot;

class HostConnection {
  final VpnStatus status;
  final ConnectionPlan? plan;
  final RuntimeSnapshot? traffic;
  const HostConnection(this.status, {this.plan, this.traffic});
  bool get connected => status == VpnStatus.connected;
}

class ConnectionHostException implements Exception {
  final String reason;
  final PlatformPermissionResult? permission;
  const ConnectionHostException(this.reason, {this.permission});
  @override
  String toString() => reason;
}

/// Native status owns VPN state. Xray metrics supplies live session counters;
/// saved host snapshots supply background counters. Only the App writes totals.
class ConnectionRuntimeHost {
  final AppHostApi _host = AppHostApi();
  final String? _runDirectory;
  final RuntimeStateReader? _readFiles;
  final Future<XrayMetricsVars> Function(int port)? _metrics;
  final Future<VpnStatus> Function()? _readStatus;
  final Future<NativeVpnCommandResult> Function(ConnectionPlan plan)? _startVpn;
  final Future<NativeVpnCommandResult> Function()? _stopVpn;
  final Duration startTimeout;
  final Duration stopTimeout;
  final Duration pollInterval;

  ConnectionRuntimeHost({
    this._runDirectory,
    RuntimeStateReader? readRuntimeFiles,
    Future<XrayMetricsVars> Function(int port)? readMetrics,
    this._readStatus,
    this._startVpn,
    this._stopVpn,
    this.startTimeout = const Duration(seconds: 30),
    this.stopTimeout = const Duration(seconds: 15),
    this.pollInterval = const Duration(milliseconds: 200),
  }) : _readFiles = readRuntimeFiles,
       _metrics = readMetrics;

  String get _directory => _runDirectory ?? VpnConstants.runDir;
  late final _accounting = TrafficAccounting(
    path: p.join(_directory, 'traffic-totals.json'),
    readRuntimeFiles: _files,
  );

  Future<VpnStatus> _status() async {
    final readStatus = _readStatus;
    if (readStatus != null) {
      return readStatus();
    }
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

  Future<RuntimeStateFiles> _files(List<String> removeSessionIds) async {
    final reader = _readFiles;
    if (reader != null) {
      return reader(removeSessionIds);
    }
    if (_runDirectory == null && await _host.useSystemExtension()) {
      final text = await _host
          .readRuntimeState(removeSessionIds: removeSessionIds)
          .timeout(const Duration(seconds: 8));
      return text == null
          ? const RuntimeStateFiles()
          : RuntimeStateFiles.fromJson(_jsonObject(text));
    }
    final current = await _readSnapshot(
      File(p.join(_directory, 'runtime.json')),
    );
    final archiveDirectory = Directory(p.join(_directory, 'runtime-sessions'));
    final archiveType = await FileSystemEntity.type(
      archiveDirectory.path,
      followLinks: false,
    );
    if (archiveType != FileSystemEntityType.notFound &&
        archiveType != FileSystemEntityType.directory) {
      throw const FormatException('Invalid runtime archive directory');
    }
    for (final id in removeSessionIds.toSet()) {
      if (!_safeId.hasMatch(id) || id == current?.sessionId) {
        continue;
      }
      final file = File(p.join(archiveDirectory.path, '$id.json'));
      try {
        if ((await _readSnapshot(file))?.sessionId == id) {
          await file.delete();
        }
      } on Exception {
        // The returned archive keeps its watermark when deletion failed.
      }
    }
    final archived = <RuntimeSnapshot>[];
    if (await archiveDirectory.exists()) {
      await for (final entity in archiveDirectory.list(followLinks: false)) {
        if (entity is! File || p.extension(entity.path) != '.json') {
          continue;
        }
        final id = p.basenameWithoutExtension(entity.path);
        if (!_safeId.hasMatch(id)) {
          continue;
        }
        final snapshot = await _readSnapshot(entity);
        if (snapshot != null && snapshot.sessionId == id) {
          archived.add(snapshot);
        }
      }
    }
    return RuntimeStateFiles(current: current, archived: archived);
  }

  static final _safeId = RegExp(r'^[a-f0-9]{32}$');

  static Map<String, dynamic> _jsonObject(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid runtime state');
    }
    return json;
  }

  static Future<RuntimeSnapshot?> _readSnapshot(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return null;
    }
    if (type != FileSystemEntityType.file || await file.length() > 65536) {
      throw const FormatException('Invalid runtime state file');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 65536) {
      throw const FormatException('Invalid runtime state size');
    }
    return RuntimeSnapshot.fromJson(_jsonObject(utf8.decode(bytes)));
  }

  Future<RuntimeSnapshot?> readSavedTraffic() => _accounting.read();

  Future<RuntimeSnapshot?> resetTraffic([ConnectionPlan? plan]) async {
    if (plan != null) {
      try {
        await query(plan);
      } on Exception {
        // An unavailable metrics endpoint must not prevent an App-only reset.
      }
    }
    return _accounting.read(reset: true);
  }

  Future<XrayMetricsVars> _readMetrics(int port) async {
    final reader = _metrics;
    if (reader != null) {
      return reader(port);
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 2)
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/debug/vars'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw const ConnectionHostException('runtimeQueryFailed');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 3))) {
        bytes.addAll(chunk);
        if (bytes.length > 1048576) {
          throw const FormatException('Invalid metrics response size');
        }
      }
      try {
        return XrayMetricsVars.fromJson(_jsonObject(utf8.decode(bytes)));
      } on TypeError {
        throw const FormatException('Invalid metrics counters');
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<RuntimeSnapshot> query(ConnectionPlan plan) async {
    final before = (await _files(const [])).current;
    if (before == null || before.planId != plan.id || before.endedAtMs != 0) {
      throw const ConnectionHostException('runtimePlanMismatch');
    }
    final port = int.tryParse(plan.request.metricsPort ?? '');
    if (port == null || port < 1 || port > 65535) {
      throw const ConnectionHostException('runtimeMetricsUnavailable');
    }
    final counters = (await _readMetrics(port)).tunIn;
    final uplink = counters?.uplink;
    final downlink = counters?.downlink;
    if (uplink == null || downlink == null || uplink < 0 || downlink < 0) {
      throw const ConnectionHostException('runtimeMetricsUnavailable');
    }
    final after = (await _files(const [])).current;
    if (after == null ||
        after.sessionId != before.sessionId ||
        after.planId != plan.id ||
        after.endedAtMs != 0) {
      throw const ConnectionHostException('runtimeSessionChanged');
    }
    // Accounting rechecks current inside its shared queue, including when this
    // request waited behind a reset or archive cleanup from another host object.
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

  Future<HostConnection> inspect(Iterable<ConnectionPlan> knownPlans) async {
    final status = await _status();
    RuntimeSnapshot? saved;
    try {
      saved = await readSavedTraffic();
    } on Exception {
      // Status remains native-owned when saved statistics cannot be read.
    }
    if (status == VpnStatus.disconnected) {
      return HostConnection(status, traffic: saved);
    }
    final plans = {for (final plan in knownPlans) plan.id: plan};
    if (saved != null &&
        !plans.containsKey(saved.planId) &&
        _safeId.hasMatch(saved.planId)) {
      try {
        final file = File(
          p.join(_directory, 'plans', saved.planId, 'plan.json'),
        );
        if (await file.exists()) {
          final plan = ConnectionPlan.decode(await file.readAsString());
          if (plan.id == saved.planId) {
            plans[plan.id] = plan;
          }
        }
      } on Exception {
        // A damaged old plan does not change native connection status.
      }
    }
    final plan = plans[saved?.planId];
    if (plan != null) {
      try {
        return HostConnection(status, plan: plan, traffic: await query(plan));
      } on Exception {
        // A saved counter is not a successful live sample.
      }
    }
    return HostConnection(
      status,
      traffic: saved?.withCounters(
        uplink: saved.uplink,
        downlink: saved.downlink,
        sampledAtMs: saved.sampledAtMs,
        available: false,
        error: 'runtimeMetricsUnavailable',
      ),
    );
  }

  Future<NativeVpnCommandResult> _start(ConnectionPlan plan) async {
    final startVpn = _startVpn;
    if (startVpn != null) {
      return startVpn(plan);
    }
    await plan.request.writeToStartFile();
    final policy = plan.configuration.policy;
    final windows = plan.platform == ConnectionPlatform.windows;
    return _host.startVpn(
      windowsConfigYaml: windows
          ? buildWindowsTun2SocksConfig(
              plan.request.socksPort!,
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

  Future<HostConnection> start(ConnectionPlan plan) async {
    String? previousSession;
    var previousReadable = true;
    try {
      previousSession = (await _files(const [])).current?.sessionId;
    } on Exception {
      // A stopped System Extension may not serve files until it is started.
      previousReadable = false;
    }
    final requestedAt = DateTime.now().millisecondsSinceEpoch;
    final result = await _start(plan);
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
      final current = await inspect([plan]);
      if (current.connected &&
          current.plan?.id == plan.id &&
          current.traffic?.sessionId != previousSession &&
          current.traffic?.available == true &&
          (previousReadable || current.traffic!.startedAtMs >= requestedAt)) {
        return current;
      }
      await Future<void>.delayed(pollInterval);
    }
    throw const ConnectionHostException('startTimeout');
  }

  Future<HostConnection> stop(ConnectionPlan? plan) async {
    final result = await (_stopVpn?.call() ?? _host.stopVpn());
    if (result.state != NativeVpnCommandState.success) {
      throw const ConnectionHostException('stopFailed');
    }
    final deadline = DateTime.now().add(stopTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final status = await _status();
      if (status == VpnStatus.disconnected) {
        RuntimeSnapshot? saved;
        try {
          saved = await readSavedTraffic();
        } on Exception {
          // Native shutdown does not depend on statistics persistence.
        }
        return HostConnection(status, traffic: saved);
      }
      await Future<void>.delayed(pollInterval);
    }
    throw const ConnectionHostException('stopTimeout');
  }
}
