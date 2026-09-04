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
    final fixtures = Directory(
      p.join('..', 'references', 'onexray-refactor-validation', 'fixtures'),
    ).absolute;
    await fixtures.create(recursive: true);
    directory = await fixtures.createTemp('runtime-host-');
    addTearDown(() => directory.delete(recursive: true));
  });

  test(
    'private plan reader shares the file used to identify a live session',
    () async {
      final plan = _plan();
      final file = File(p.join(directory.path, 'plans', plan.id, 'plan.json'));
      await file.parent.create(recursive: true);
      await file.writeAsString(plan.encode());
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readRuntimeState: (_) async =>
            RuntimeState(current: _snapshot('a', plan.id, 10, 20)),
      );
      expect((await host.readPlan(plan.id))?.encode(), plan.encode());
      final running = await host.inspect(
        [],
        observedStatus: VpnStatus.connected,
      );
      expect(running.plan?.id, plan.id);
      final stopped = await host.inspect(
        [],
        observedStatus: VpnStatus.disconnected,
      );
      expect(stopped.connected, false);
      expect(stopped.plan, isNull);
    },
  );

  test('missing, invalid and damaged plan references return no plan', () async {
    final plan = _plan();
    final host = ConnectionRuntimeHost(runDirectory: directory.path);
    for (final id in [null, '', '../plan', _id('F'), plan.id]) {
      expect(await host.readPlan(id), isNull);
    }
    final file = File(p.join(directory.path, 'plans', plan.id, 'plan.json'));
    await file.parent.create(recursive: true);
    for (final text in [
      'broken json',
      '[]',
      '{}',
      jsonEncode({'version': 1, 'id': plan.id, 'request': []}),
      jsonEncode({...plan.toJson(), 'id': _id('b')}),
    ]) {
      await file.writeAsString(text);
      expect(await host.readPlan(plan.id), isNull);
    }
  });

  test('private plan reader ignores linked directories and files', () async {
    final plan = _plan();
    final outside = Directory(p.join(directory.path, 'outside'));
    await outside.create();
    final file = File(p.join(outside.path, 'plan.json'));
    await file.writeAsString(plan.encode());
    final plans = Directory(p.join(directory.path, 'plans'));
    await plans.create();
    final link = Link(p.join(plans.path, plan.id));
    await link.create(outside.path);
    final host = ConnectionRuntimeHost(runDirectory: directory.path);
    expect(await host.readPlan(plan.id), isNull);
    await link.delete();
    await Directory(link.path).create();
    await Link(p.join(link.path, 'plan.json')).create(file.path);
    expect(await host.readPlan(plan.id), isNull);
  }, skip: Platform.isWindows);

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
              'otherIn': {'uplink': 999, 'downlink': 999},
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
      readRuntimeState: (_) async => RuntimeState(current: current),
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
      readRuntimeState: (_) async =>
          RuntimeState(current: _snapshot('a', plan.id, 10, 20)),
      readMetrics: (_) async => throw const SocketException('Not available'),
      readStatus: () async => VpnStatus.connected,
    );
    final state = await host.inspect([plan], readMetrics: true);
    expect(state.connected, true);
    expect(state.plan?.id, plan.id);
    expect(state.traffic!.uplink, 10);
    expect(state.traffic!.totalUplink, 10);
    expect(state.traffic!.available, false);
    expect(state.traffic!.error, 'runtimeMetricsUnavailable');
  });

  test('status reconciliation uses saved facts without metrics or echoing native events', () async {
    final plan = _plan();
    var statusReads = 0;
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readStatus: () async {
        statusReads++;
        return VpnStatus.connected;
      },
      readRuntimeState: (_) async =>
          RuntimeState(current: _snapshot('a', plan.id, 10, 20)),
      readMetrics: (_) async =>
          throw StateError('No metrics during reconciliation'),
    );
    final initial = await host.inspect([plan]);
    expect(statusReads, 1);
    expect(initial.plan?.id, plan.id);
    expect(initial.traffic!.available, false);
    final event = await host.inspect([
      plan,
    ], observedStatus: VpnStatus.disconnected);
    expect(statusReads, 1);
    expect(event.status, VpnStatus.disconnected);
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
        readRuntimeState: (_) async => RuntimeState(current: current),
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

  test('start skips a healthy old snapshot until native confirms a different live session', () async {
    final plan = _plan();
    var current = _snapshot('a', plan.id, 1, 2);
    var statusReads = 0;
    var starts = 0;
    var metricReads = 0;
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readRuntimeState: (_) async => RuntimeState(current: current),
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

  test(
    'a new snapshot without working metrics cannot confirm startup',
    () async {
      final plan = _plan();
      var current = _snapshot('a', plan.id, 1, 2);
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readRuntimeState: (_) async => RuntimeState(current: current),
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
    },
  );

  test(
    'unavailable pre-start endpoint does not block a freshly started session',
    () async {
      final plan = _plan();
      RuntimeSnapshot? current;
      final host = ConnectionRuntimeHost(
        runDirectory: directory.path,
        readRuntimeState: (_) async {
          if (current == null) {
            throw const SocketException('Core not started');
          }
          return RuntimeState(current: current);
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

  test('runtime HTTP authenticates requests and rejects invalid sessions or redirects', () async {
    await File(p.join(directory.path, 'runtime.json'))
        .writeAsString('invalid legacy state');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final plan = _plan(runtimePort: server.port);
    final valid = _snapshot('a', plan.id, 1, 2).toJson();
    Object? current = valid;
    var redirect = false;
    final paths = <String>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      expect(request.method, 'GET');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer ${plan.runtime.token}',
      );
      if (redirect && request.uri.path == '/runtime') {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(HttpHeaders.locationHeader, '/forwarded');
      } else {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'current': current, 'archived': []}),
        );
      }
      await request.response.close();
    });
    var metricsReads = 0;
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readMetrics: (_) async {
        metricsReads++;
        return _metrics(1, 2);
      },
    );
    expect((await host.query(plan)).totalUplink, 1);
    expect(paths, everyElement('/runtime'));
    expect(metricsReads, 1);
    for (final invalid in <({Object? current, Matcher error})>[
      (current: null, error: _reason('runtimePlanMismatch')),
      (current: {...valid, 'session': null}, error: isA<FormatException>()),
      (
        current: {
          ...valid,
          'session': {...(valid['session'] as Map), 'id': ''},
        },
        error: isA<FormatException>(),
      ),
      (
        current: _snapshot('a', _id('d'), 1, 2).toJson(),
        error: _reason('runtimePlanMismatch'),
      ),
    ]) {
      current = invalid.current;
      await expectLater(host.query(plan), throwsA(invalid.error));
    }
    expect(metricsReads, 1);
    current = valid;
    paths.clear();
    redirect = true;
    await expectLater(host.query(plan), throwsA(_reason('runtimeQueryFailed')));
    expect(paths, ['/runtime']);
  });

  test('HTTP archives settle before ack and offline reset preserves session watermarks', () async {
    await Directory(p.join(directory.path, 'runtime.json')).create();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var stopped = false;
    addTearDown(() async {
      if (!stopped) await server.close(force: true);
    });
    final plan = _plan(runtimePort: server.port);
    var current = _snapshot('b', plan.id, 3, 6);
    var archived = [_snapshot('a', plan.id, 7, 14, ended: 9)];
    final acknowledged = <List<String>>[];
    final ledgerFile = File(p.join(directory.path, 'traffic-totals.json'));
    Future<void> respond(HttpRequest request) async {
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer ${_id('e')}',
      );
      if (request.uri.path == '/runtime/ack') {
        expect(request.method, 'POST');
        expect(request.headers.contentType?.mimeType, 'application/json');
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        final ids = List<String>.from(body['removeSessionIds'] as List);
        expect(ids, isNot(contains(current.sessionId)));
        final ledger = jsonDecode(await ledgerFile.readAsString()) as Map;
        final settled = ledger['sessions'] as Map;
        for (final id in ids) {
          expect(settled.containsKey(id), true);
          final snapshot = archived.singleWhere((row) => row.sessionId == id);
          expect((settled[id] as Map)['uplink'], snapshot.uplink);
        }
        acknowledged.add(ids);
        archived.removeWhere((row) => ids.contains(row.sessionId));
      } else {
        expect(request.method, 'GET');
        expect(request.uri.path, '/runtime');
      }
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'current': current.toJson(),
          'archived': [for (final row in archived) row.toJson()],
        }),
      );
      await request.response.close();
    }

    server.listen(respond);
    final host = ConnectionRuntimeHost(
      runDirectory: directory.path,
      readStatus: () async {
        expect(stopped, true);
        return VpnStatus.disconnected;
      },
      stopVpn: () async {
        await server.close(force: true);
        stopped = true;
        return _success();
      },
      readMetrics: (_) async => throw StateError('No metrics flush on stop'),
    );
    final connected = await host.inspect([
      plan,
    ], observedStatus: VpnStatus.connected);
    expect(connected.traffic!.totalUplink, 10);
    expect(acknowledged, [
      [_id('a')],
    ]);
    expect((await host.readSavedTraffic())!.totalUplink, 10);

    final disconnected = await host.stop(plan);
    expect(disconnected.connected, false);
    expect(disconnected.traffic!.uplink, 3);
    expect(disconnected.traffic!.totalUplink, 10);
    expect(disconnected.traffic!.available, false);
    final reopened = ConnectionRuntimeHost(runDirectory: directory.path);
    final unavailable = await reopened.inspect([
      plan,
    ], observedStatus: VpnStatus.connected);
    expect(unavailable.connected, true);
    expect(unavailable.plan, isNull);
    expect(unavailable.traffic!.totalUplink, 10);
    expect(unavailable.traffic!.available, false);
    await reopened.inspect([plan], observedStatus: VpnStatus.disconnected);
    final reset = (await reopened.resetTraffic())!;
    expect(reset.uplink, 3);
    expect(reset.totalUplink, 0);
    expect(reset.totalDownlink, 0);
    expect(reset.resetGeneration, 1);

    final nextServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => nextServer.close(force: true));
    final nextPlan = _plan(runtimePort: nextServer.port, planId: _id('d'));
    current = _snapshot('c', nextPlan.id, 2, 4);
    archived = [_snapshot('b', plan.id, 5, 10, ended: 9)];
    nextServer.listen(respond);
    final next = await reopened.inspect([
      nextPlan,
    ], observedStatus: VpnStatus.connected);
    expect(next.plan?.id, nextPlan.id);
    expect(next.traffic!.totalUplink, 4);
    expect(next.traffic!.totalDownlink, 8);
    expect(next.traffic!.resetGeneration, 1);
    expect(acknowledged, [
      [_id('a')],
      [_id('b')],
    ]);
    expect((await reopened.readSavedTraffic())!.totalUplink, 4);
    expect(acknowledged, hasLength(2));
  });

  test(
    'startup request finds an uncommitted plan but HTTP confirms its session',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final previous = _plan(runtimePort: 0);
      final starting = _plan(runtimePort: server.port, planId: _id('b'));
      final planFile = File(
        p.join(directory.path, 'plans', starting.id, 'plan.json'),
      );
      await planFile.parent.create(recursive: true);
      await planFile.writeAsString(starting.encode());
      await File(p.join(directory.path, 'start.json'))
          .writeAsString(jsonEncode(starting.request.toJson()));
      var reads = 0;
      server.listen((request) async {
        reads++;
        expect(request.method, 'GET');
        expect(request.uri.path, '/runtime');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer ${starting.runtime.token}',
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'current': _snapshot('c', starting.id, 20, 40).toJson(),
            'archived': [],
          }),
        );
        await request.response.close();
      });
      final host = ConnectionRuntimeHost(runDirectory: directory.path);
      final result = await host.inspect([
        previous,
      ], observedStatus: VpnStatus.connected);
      expect(reads, 1);
      expect(result.connected, true);
      expect(result.plan?.id, starting.id);
      expect(result.traffic!.sessionId, _id('c'));
      expect(result.traffic!.totalUplink, 20);
    },
  );
}

Matcher _reason(String reason) => isA<ConnectionHostException>().having(
  (error) => error.reason,
  'reason',
  reason,
);

NativeVpnCommandResult _success() =>
    NativeVpnCommandResult(state: NativeVpnCommandState.success);

XrayMetricsVars _metrics(int up, int down) => XrayMetricsVars(
  XrayMetricsStats(XrayMetricsInboundStats(XrayTrafficCounter(up, down))),
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

String _id(String digit) => List.filled(32, digit).join();

ConnectionPlan _plan({
  int port = 18003,
  int runtimePort = 18004,
  String? listen,
  String? token,
  String? planId,
  String platform = 'android',
}) {
  final id = planId ?? _id('f');
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(
      '{}',
      runtime: ManagedRuntimeRequest(
        statePath: '/fixture/run/runtime.json',
        planId: id,
        listen: listen ?? '127.0.0.1:$runtimePort',
        token: token ?? _id('e'),
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
