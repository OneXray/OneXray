import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/xray/metrics/model.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;

  setUp(() async {
    final fixtures = Directory(
      p.join('..', 'references', 'onexray-refactor-validation', 'fixtures'),
    ).absolute;
    await fixtures.create(recursive: true);
    directory = await fixtures.createTemp('runtime-host-');
    addTearDown(() => directory.delete(recursive: true));
  });

  test('start.json is the only persisted runtime descriptor', () async {
    final runtime = _runtime();
    final originalPath = runtime.request.coreInvokeText;
    await File(p.join(directory.path, 'start.json'))
        .writeAsString(jsonEncode(runtime.request.toJson()));
    final restored = await ConnectionRuntimeHost(runDirectory: directory.path)
        .readRuntime();

    expect(restored?.identity, runtime.identity);
    expect(restored?.nodeIds, {1});
    expect(restored?.entries.single.name, 'Server');
    expect(restored?.request.coreInvokeText, originalPath);
    expect(await Directory(p.join(directory.path, 'plans')).exists(), false);
  });

  test('invalid start metadata is ignored', () async {
    await File(p.join(directory.path, 'start.json')).writeAsString(
      jsonEncode(StartVpnRequest(null, null, null, '{}').toJson()),
    );

    expect(
      await ConnectionRuntimeHost(runDirectory: directory.path).readRuntime(),
      isNull,
    );
  });

  test('unknown start metadata enums are ignored', () async {
    final request = _runtime().request;
    final metadata = jsonDecode(request.metadataJson!) as Map<String, dynamic>;
    metadata['platform'] = 'unknown';
    request.metadataJson = jsonEncode(metadata);
    await File(p.join(directory.path, 'start.json'))
        .writeAsString(jsonEncode(request.toJson()));

    expect(
      await ConnectionRuntimeHost(runDirectory: directory.path).readRuntime(),
      isNull,
    );
  });

  test(
    'inspect associates native status with the active start request',
    () async {
      final runtime = _runtime();
      final traffic = _traffic(10, 20);
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readRuntimeSnapshot: () async => traffic,
        readStatus: () async => VpnStatus.connected,
      );

      final connected = await host.inspect([runtime]);
      expect(connected.status, VpnStatus.connected);
      expect(connected.runtime?.identity, runtime.identity);
      expect(connected.traffic?.totalUplink, 10);
    },
  );

  test('foreground metrics update the current session', () async {
    final runtime = _runtime();
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readRuntimeSnapshot: () async => _traffic(10, 20),
      readMetrics: (_) async => _metrics(15, 30),
    );

    final traffic = await host.query(runtime);
    expect(traffic.uplink, 15);
    expect(traffic.downlink, 30);
    expect(traffic.totalUplink, 15);
  });

  test(
    'start confirms a fresh session and stop does not restore old input',
    () async {
      final runtime = _runtime();
      await File(p.join(directory.path, 'traffic-totals.json'))
          .writeAsString('{"version":1,"sessions":{},"resetGeneration":0}');
      var status = VpnStatus.disconnected;
      var traffic = _traffic(0, 0, startedAtMs: 0);
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readRuntimeSnapshot: () async => traffic,
        readMetrics: (_) async => _metrics(0, 0),
        readStatus: () async => status,
        startVpn: (_) async {
          status = VpnStatus.connected;
          traffic = _traffic(
            0,
            0,
            startedAtMs: DateTime.now().millisecondsSinceEpoch,
          );
          return NativeVpnCommandResult(state: NativeVpnCommandState.success);
        },
        stopVpn: () async {
          status = VpnStatus.disconnected;
          return NativeVpnCommandResult(state: NativeVpnCommandState.success);
        },
      );

      expect((await host.start(runtime)).runtime?.identity, runtime.identity);
      expect((await host.stop()).status, VpnStatus.disconnected);
    },
  );
}

ConnectionRuntime _runtime() {
  final configuration = ConnectionConfiguration();
  final server = ResolvedServer(
    id: 1,
    sourceId: 7,
    outbound: {'protocol': 'freedom', 'tag': 'Server'},
  );
  const xrayJson = '{"outbounds":[]}';
  final compiled = CompiledConnection(
    xrayJson: xrayJson,
    entries: [server],
    finalExit: null,
    nodeTags: const {},
    ruleTags: const {},
  );
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(
      xrayJson,
      runtime: const ManagedRuntimeRequest(
        statePath: '/fixture/run/runtime.json',
        listen: '127.0.0.1:18004',
        token: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      ),
    ).toJson(),
  );
  return ConnectionRuntime.create(
    configuration: configuration,
    compiled: compiled,
    platform: ConnectionPlatform.android,
    request: StartVpnRequest(null, null, '18003', jsonEncode(invoke.toJson())),
  );
}

RuntimeSnapshot _traffic(int up, int down, {int startedAtMs = 1}) =>
    RuntimeSnapshot(
      sessionId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      startedAtMs: startedAtMs,
      endedAtMs: 0,
      uplink: up,
      downlink: down,
      available: true,
      sampledAtMs: 3,
      savedAtMs: 4,
      error: '',
    );

XrayMetricsVars _metrics(int up, int down) => XrayMetricsVars(
  XrayMetricsStats(XrayMetricsInboundStats(XrayTrafficCounter(up, down))),
);
