import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connect/compiler.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/runtime_host.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/shared/xray/metrics/model.dart';
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
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readMetrics: (_) async => throw const FormatException(),
        readStatus: () async => VpnStatus.connected,
      );

      final connected = await host.inspect([runtime]);
      expect(connected.status, VpnStatus.connected);
      expect(connected.runtime?.identity, runtime.identity);
      expect(connected.traffic, isNull);
    },
  );

  test(
    'metrics HTTP is the only source and writes no accounting files',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <String>[];
      server.listen((request) async {
        requests.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_metrics(15, 30).toJson()));
        await request.response.close();
      });
      final runtime = _runtime();
      runtime.request.metricsPort = server.port.toString();
      final host = ConnectionRuntimeHost(runDirectory: directory.path);

      final traffic = await host.query(runtime);
      expect(traffic.uplink, 15);
      expect(traffic.downlink, 30);
      expect(requests, ['/debug/vars']);
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test(
    'idle metrics have zero counters; malformed metrics are unavailable',
    () async {
      final runtime = _runtime();
      var metrics = const XrayMetricsVars(XrayMetricsStats(null));
      final host = ConnectionRuntimeHost(readMetrics: (_) async => metrics);
      final idle = await host.query(runtime);
      expect(idle.uplink, 0);
      expect(idle.downlink, 0);
      metrics = const XrayMetricsVars(null);
      await expectLater(host.query(runtime), throwsFormatException);
      metrics = _metrics(-1, 0);
      await expectLater(host.query(runtime), throwsFormatException);
    },
  );

  test(
    'start and stop depend on native state, not metrics availability',
    () async {
      final runtime = _runtime();
      var status = VpnStatus.disconnected;
      var metricReads = 0;
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readMetrics: (_) async {
          metricReads++;
          throw const FormatException();
        },
        readStatus: () async => status,
        startVpn: (_) async {
          status = VpnStatus.connected;
          return NativeVpnCommandResult(state: NativeVpnCommandState.success);
        },
        stopVpn: () async {
          status = VpnStatus.disconnected;
          return NativeVpnCommandResult(state: NativeVpnCommandState.success);
        },
      );

      expect((await host.start(runtime)).runtime?.identity, runtime.identity);
      expect((await host.stop()).status, VpnStatus.disconnected);
      expect(metricReads, 0);
      expect(await directory.list().toList(), isEmpty);
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
  );
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(xrayJson).toJson(),
  );
  return ConnectionRuntime.create(
    configuration: configuration,
    compiled: compiled,
    platform: ConnectionPlatform.android,
    request: StartVpnRequest(null, null, '18003', jsonEncode(invoke.toJson())),
  );
}

XrayMetricsVars _metrics(int up, int down) => XrayMetricsVars(
  XrayMetricsStats(XrayMetricsInboundStats(XrayTrafficCounter(up, down))),
);
