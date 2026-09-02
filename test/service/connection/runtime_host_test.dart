import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/traffic_accounting.dart';
import 'package:onexray/service/xray/metrics/model.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('onexray-runtime-host-');
    addTearDown(() => directory.delete(recursive: true));
  });

  test('Windows replay revocation preserves other files and restores exact metadata', () async {
    final plan = _plan(platform: 'windows');
    final planDirectory = Directory(p.join(directory.path, 'plans', plan.id));
    await planDirectory.create(recursive: true);
    final file = File(p.join(planDirectory.path, 'runtime-config.json'));
    final text = '  ${jsonEncode(plan.runtime.toJson())}\n';
    await file.writeAsString(text);
    final preserved = [
      File(p.join(planDirectory.path, 'xray.json')),
      File(p.join(planDirectory.path, 'plan.json')),
      File(p.join(directory.path, 'start.json')),
      File(p.join(directory.path, 'runtime.json')),
    ];
    for (final other in preserved) {
      await other.writeAsString('unchanged');
    }
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readStatus: () async => VpnStatus.disconnected,
    );
    final restore = await host.revokeReplay(plan);
    expect(restore, isNotNull);
    expect(await file.exists(), false);
    expect(await host.revokeReplay(plan), isNull);
    for (final other in preserved) {
      expect(await other.readAsString(), 'unchanged');
    }
    final rollback = restore!;
    await rollback();
    expect(await file.readAsString(), text);
    await rollback();
    expect(await file.readAsString(), text);
  });

  test('replay revocation does not touch other platforms or an active Windows plan', () async {
    final file = File(
      p.join(directory.path, 'plans', _id('f'), 'runtime-config.json'),
    );
    await file.parent.create(recursive: true);
    for (final platform in ['ios', 'macos', 'android', 'linux']) {
      final plan = _plan(platform: platform);
      final text = jsonEncode(plan.runtime.toJson());
      await file.writeAsString(text);
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readStatus: () async => throw StateError('Not a Windows operation'),
      );
      expect(await host.revokeReplay(plan), isNull);
      expect(await file.readAsString(), text);
    }
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readStatus: () async => VpnStatus.connected,
    );
    await expectLater(
      host.revokeReplay(_plan(platform: 'windows')),
      throwsA(_reason('replayPlanStillRunning')),
    );
    expect(await file.exists(), true);
  });

  test('replay revocation rejects metadata for another plan', () async {
    final plan = _plan(platform: 'windows');
    final file = File(
      p.join(directory.path, 'plans', plan.id, 'runtime-config.json'),
    );
    await file.parent.create(recursive: true);
    final text = jsonEncode({...plan.runtime.toJson(), 'planId': _id('b')});
    await file.writeAsString(text);
    final host = ConnectionRuntimeHost(runDirectory: directory.path);
    await expectLater(host.revokeReplay(plan), throwsFormatException);
    expect(await file.readAsString(), text);
  });

  test('replay revocation rejects a linked plan directory', () async {
    final plan = _plan(platform: 'windows');
    final outside = Directory(p.join(directory.path, 'outside'));
    await outside.create();
    final file = File(p.join(outside.path, 'runtime-config.json'));
    final text = jsonEncode(plan.runtime.toJson());
    await file.writeAsString(text);
    final plans = Directory(p.join(directory.path, 'plans'));
    await plans.create();
    await Link(p.join(plans.path, plan.id)).create(outside.path);
    final host = ConnectionRuntimeHost(runDirectory: directory.path);
    await expectLater(host.revokeReplay(plan), throwsFormatException);
    expect(await file.readAsString(), text);
  }, skip: Platform.isWindows);

  test('native metrics uses GET debug vars and App reset never changes session counters', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var up = 15;
    var requests = 0;
    server.listen((request) async {
      requests++;
      expect(request.method, 'GET');
      expect(request.uri.path, '/debug/vars');
      expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'stats': {
            'inbound': {
              'tunIn': {'uplink': up, 'downlink': up * 2},
              'pingIn': {'uplink': 999, 'downlink': 999},
            },
          },
        }),
      );
      await request.response.close();
    });
    final plan = _plan(port: server.port);
    final current = _snapshot('a', plan.id, 10, 20);
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readRuntimeFiles: (_) async => RuntimeStateFiles(current: current),
    );
    final first = await host.query(plan);
    expect(first.uplink, 15);
    expect(first.totalUplink, 15);
    final reset = (await host.resetTraffic(plan))!;
    expect(reset.uplink, 15);
    expect(reset.totalUplink, 0);
    expect(reset.resetGeneration, 1);
    up = 19;
    final next = await host.query(plan);
    expect(next.uplink, 19);
    expect(next.totalUplink, 4);
    expect(next.totalDownlink, 8);
    expect(requests, 3);
  });

  test('metrics failure preserves native connected status and marks saved counters unavailable', () async {
    final plan = _plan();
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readRuntimeFiles: (_) async =>
          RuntimeStateFiles(current: _snapshot('a', plan.id, 10, 20)),
      readMetrics: (_) async => throw const SocketException('Not available'),
      readStatus: () async => VpnStatus.connected,
    );
    final state = await host.inspect([plan]);
    expect(state.connected, true);
    expect(state.plan, isNull);
    expect(state.traffic!.uplink, 10);
    expect(state.traffic!.totalUplink, 10);
    expect(state.traffic!.available, false);
    expect(state.traffic!.error, 'runtimeMetricsUnavailable');
  });

  test(
    'a session change while HTTP is pending discards the late counters',
    () async {
      final plan = _plan();
      var current = _snapshot('a', plan.id, 1, 2);
      final entered = Completer<void>();
      final result = Completer<XrayMetricsVars>();
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readRuntimeFiles: (_) async => RuntimeStateFiles(current: current),
        readMetrics: (_) {
          entered.complete();
          return result.future;
        },
      );
      final query = host.query(plan);
      final rejected = expectLater(
        query,
        throwsA(_reason('runtimeSessionChanged')),
      );
      await entered.future;
      current = _snapshot('b', plan.id, 3, 6);
      result.complete(_metrics(100, 200));
      await rejected;
      expect(
        await File(p.join(directory.path, 'traffic-totals.json')).exists(),
        false,
      );
      expect((await host.readSavedTraffic())!.totalUplink, 3);
    },
  );

  test('start skips a healthy old file until native confirms a different live session', () async {
    final plan = _plan();
    var current = _snapshot('a', plan.id, 1, 2);
    var statusReads = 0;
    var starts = 0;
    var metricReads = 0;
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readRuntimeFiles: (_) async => RuntimeStateFiles(current: current),
      readStatus: () async {
        if (++statusReads == 2) {
          current = _snapshot('b', plan.id, 3, 6);
        }
        return VpnStatus.connected;
      },
      startVpn: (_) async {
        starts++;
        return _success();
      },
      readMetrics: (_) async {
        metricReads++;
        return _metrics(current.uplink, current.downlink);
      },
      pollInterval: Duration.zero,
    );
    final started = await host.start(plan);
    expect(starts, 1);
    expect(metricReads, 2);
    expect(started.traffic!.sessionId, _id('b'));
    expect(started.plan!.id, plan.id);
  });

  test('a new file without working metrics cannot confirm startup', () async {
    final plan = _plan();
    var current = _snapshot('a', plan.id, 1, 2);
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readRuntimeFiles: (_) async => RuntimeStateFiles(current: current),
      readStatus: () async => VpnStatus.connected,
      startVpn: (_) async {
        current = _snapshot('b', plan.id, 3, 6);
        return _success();
      },
      readMetrics: (_) async => throw const SocketException('Not ready'),
      startTimeout: const Duration(milliseconds: 30),
      pollInterval: Duration.zero,
    );
    await expectLater(host.start(plan), throwsA(_reason('startTimeout')));
    final actual = await host.inspect([plan]);
    expect(actual.connected, true);
    expect(actual.traffic!.available, false);
  });

  test(
    'unavailable pre-start provider does not block a freshly started session',
    () async {
      final plan = _plan();
      RuntimeSnapshot? current;
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readRuntimeFiles: (_) async {
          if (current == null) {
            throw const SocketException('Provider not started');
          }
          return RuntimeStateFiles(current: current);
        },
        readStatus: () async => VpnStatus.connected,
        startVpn: (_) async {
          current = RuntimeSnapshot(
            sessionId: _id('b'),
            planId: plan.id,
            startedAtMs: DateTime.now().millisecondsSinceEpoch,
            endedAtMs: 0,
            uplink: 0,
            downlink: 0,
            available: false,
            sampledAtMs: 0,
            savedAtMs: DateTime.now().millisecondsSinceEpoch,
            error: '',
          );
          return _success();
        },
        readMetrics: (_) async => _metrics(0, 0),
      );
      final result = await host.start(plan);
      expect(result.connected, true);
      expect(result.traffic!.sessionId, _id('b'));
      expect(result.traffic!.available, true);
    },
  );

  test(
    'stop calls native first and reads its final file without a metrics flush',
    () async {
      final plan = _plan();
      var stopped = false;
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readRuntimeFiles: (_) async {
          expect(stopped, true);
          return RuntimeStateFiles(
            current: _snapshot('a', plan.id, 23, 46, ended: 9),
          );
        },
        readStatus: () async => VpnStatus.disconnected,
        stopVpn: () async {
          stopped = true;
          return _success();
        },
        readMetrics: (_) async =>
            throw StateError('Unexpected metrics request'),
      );
      final result = await host.stop(plan);
      expect(result.connected, false);
      expect(result.traffic!.endedAtMs, 9);
      expect(result.traffic!.totalUplink, 23);
    },
  );

  test(
    'local archives are accounted and removed without deleting current',
    () async {
      final archiveDirectory = Directory(
        p.join(directory.path, 'runtime-sessions'),
      );
      await archiveDirectory.create();
      final currentFile = File(p.join(directory.path, 'runtime.json'));
      final archivedFile = File(
        p.join(archiveDirectory.path, '${_id('a')}.json'),
      );
      await currentFile.writeAsString(jsonEncode(_snapshotJson('b', 3, 6)));
      await archivedFile.writeAsString(jsonEncode(_snapshotJson('a', 7, 14)));
      final host = ConnectionRuntimeHost(runDirectory: directory.path);
      expect((await host.readSavedTraffic())!.totalUplink, 10);
      expect(await currentFile.exists(), true);
      expect(await archivedFile.exists(), false);
      expect((await host.readSavedTraffic())!.totalUplink, 10);
    },
  );

  test('local archive reader rejects a linked archive directory', () async {
    final outside = await Directory.systemTemp.createTemp(
      'onexray-archive-link-',
    );
    addTearDown(() => outside.delete(recursive: true));
    await Link(p.join(directory.path, 'runtime-sessions')).create(outside.path);
    final host = ConnectionRuntimeHost(runDirectory: directory.path);
    await expectLater(host.readSavedTraffic(), throwsFormatException);
  }, skip: Platform.isWindows);
}

Matcher _reason(String reason) => isA<ConnectionHostException>().having(
  (error) => error.reason,
  'reason',
  reason,
);

NativeVpnCommandResult _success() =>
    NativeVpnCommandResult(state: NativeVpnCommandState.success);

XrayMetricsVars _metrics(int up, int down) => XrayMetricsVars(
  XrayMetricsStats(XrayMetricsInboundStats(XrayTrafficCounter(up, down), null)),
);

RuntimeSnapshot _snapshot(
  String digit,
  String planId,
  int up,
  int down, {
  int ended = 0,
}) => RuntimeSnapshot(
  sessionId: _id(digit),
  planId: planId,
  startedAtMs: 1,
  endedAtMs: ended,
  uplink: up,
  downlink: down,
  available: true,
  sampledAtMs: 3,
  savedAtMs: 4,
  error: '',
);

Map<String, dynamic> _snapshotJson(String digit, int up, int down) => {
  'version': 1,
  'session': {
    'id': _id(digit),
    'planId': _id('f'),
    'startedAtMs': 1,
    'endedAtMs': 0,
    'uplink': up,
    'downlink': down,
  },
  'available': true,
  'sampledAtMs': 3,
  'savedAtMs': 4,
  'error': '',
};

String _id(String digit) => List.filled(32, digit).join();

ConnectionPlan _plan({int port = 18003, String platform = 'android'}) {
  final id = _id('f');
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(
      '{}',
      runtime: ManagedRuntimeRequest(
        statePath: '/fixture/run/runtime.json',
        planId: id,
      ),
    ).toJson(),
  );
  return ConnectionPlan.decode(
    jsonEncode({
      'version': 1,
      'id': id,
      'platform': platform,
      'configuration': ConnectionConfiguration().toJson(),
      'request': StartVpnRequest(
        null,
        null,
        null,
        null,
        '$port',
        jsonEncode(invoke.toJson()),
      ).toJson(),
      'xrayJson': '{}',
      'entries': [],
      'nodeTags': {},
      'ruleTags': {},
      'assetDirectory': '/fixture/assets',
    }),
  );
}
