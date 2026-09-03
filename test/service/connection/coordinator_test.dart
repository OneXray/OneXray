import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  testWidgets('native events synchronize globally without polling or metrics', (
    tester,
  ) async {
    await tester.runAsync(() => db.connectionStateDao.read());
    final events = StreamController<VpnStatus>.broadcast(sync: true);
    final plan = _plan('a');
    var status = VpnStatus.disconnected;
    var queries = 0;
    var observations = 0;
    final coordinator = ConnectionCoordinator(
      database: db,
      statusEvents: events.stream,
      needsStatusPolling: () => false,
      inspect: (_) async {
        queries++;
        events.add(status); // Native query replies also broadcast.
        return HostConnection(
          status,
          plan: status == VpnStatus.connected ? plan : null,
        );
      },
      inspectObserved: (_, value) async {
        observations++;
        return HostConnection(
          value,
          plan: value == VpnStatus.connected ? plan : null,
        );
      },
      readTraffic: (_) async =>
          throw StateError('Invisible page cannot sample'),
    );
    final initialized = coordinator.initialize(registerReferences: false);
    await tester.pump();
    await initialized;
    await tester.pump(const Duration(seconds: 20));
    expect(queries, 1);
    expect(observations, 0);

    status = VpnStatus.connected;
    events.add(status);
    await tester.pump();
    expect(coordinator.state.value.phase, ConnectionPhase.connected);
    expect(observations, 1);
    events.add(status);
    await tester.pump();
    expect(observations, 1);
    coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
    status = VpnStatus.disconnected;
    events.add(status);
    await tester.pump();
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(queries, 2);
    expect(observations, 2);
    coordinator.dispose();
    await events.close();
  });

  testWidgets(
    'metrics demand follows visibility, foreground and connection without status queries',
    (tester) async {
      await tester.runAsync(() => db.connectionStateDao.read());
      final events = StreamController<VpnStatus>.broadcast(sync: true);
      final plan = _plan('a');
      var queries = 0;
      var samples = 0;
      var status = VpnStatus.connected;
      final coordinator = ConnectionCoordinator(
        database: db,
        statusEvents: events.stream,
        needsStatusPolling: () => false,
        inspect: (_) async {
          queries++;
          return HostConnection(status, plan: plan);
        },
        inspectObserved: (_, value) async => HostConnection(value, plan: plan),
        readTraffic: (_) async => _traffic(plan, ++samples),
      );
      final initialized = coordinator.initialize(registerReferences: false);
      await tester.pump();
      await initialized;
      await tester.pump(const Duration(seconds: 3));
      expect(samples, 0);
      coordinator.setTrafficVisible(true);
      await tester.pump();
      expect(samples, 1);
      expect(coordinator.state.value.uploadSpeed, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(samples, 2);
      expect(coordinator.state.value.uploadSpeed, 100);
      expect(queries, 1);
      coordinator.setTrafficVisible(false);
      await tester.pump(const Duration(seconds: 3));
      expect(samples, 2);
      coordinator.setTrafficVisible(true);
      await tester.pump();
      expect(samples, 3);
      expect(coordinator.state.value.uploadSpeed, 0);
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(samples, 3);
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(samples, 4);
      expect(queries, 2);
      status = VpnStatus.disconnected;
      events.add(status);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(samples, 4);
      expect(coordinator.state.value.metricsAvailable, false);
      coordinator.dispose();
      await events.close();
    },
  );

  testWidgets(
    'query-only fallback runs at five seconds and stops when not needed',
    (tester) async {
      await tester.runAsync(() => db.connectionStateDao.read());
      var fallback = true;
      var reads = 0;
      final coordinator = ConnectionCoordinator(
        database: db,
        statusEvents: const Stream.empty(),
        needsStatusPolling: () => fallback,
        inspect: (_) async {
          reads++;
          return const HostConnection(VpnStatus.disconnected);
        },
      );
      final initialized = coordinator.initialize(registerReferences: false);
      await tester.pump();
      await initialized;
      await tester.pump(const Duration(seconds: 4));
      expect(reads, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(reads, 2);
      fallback = false;
      await tester.pump(const Duration(seconds: 10));
      expect(reads, 2);
      coordinator.dispose();
    },
  );

  testWidgets('late and failed metrics never revive a disconnected session', (
    tester,
  ) async {
    await tester.runAsync(() => db.connectionStateDao.read());
    final events = StreamController<VpnStatus>.broadcast(sync: true);
    final plan = _plan('a');
    final lateSample = Completer<RuntimeSnapshot>();
    var fail = false;
    final coordinator = ConnectionCoordinator(
      database: db,
      statusEvents: events.stream,
      needsStatusPolling: () => false,
      inspect: (_) async => HostConnection(VpnStatus.connected, plan: plan),
      inspectObserved: (_, status) async => HostConnection(status, plan: plan),
      readTraffic: (_) =>
          fail ? Future.error(StateError('Unavailable')) : lateSample.future,
    );
    final initialized = coordinator.initialize(registerReferences: false);
    await tester.pump();
    await initialized;
    coordinator.setTrafficVisible(true);
    await tester.pump();
    events.add(VpnStatus.disconnected);
    await tester.pump();
    lateSample.complete(_traffic(plan, 50));
    await tester.pump();
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect(coordinator.state.value.traffic, isNull);
    fail = true;
    events.add(VpnStatus.connected);
    await tester.pump();
    expect(coordinator.state.value.phase, ConnectionPhase.connected);
    expect(coordinator.state.value.metricsAvailable, false);
    expect(coordinator.state.value.issue, isNull);
    coordinator.dispose();
    await events.close();
  });

  testWidgets('native disconnect survives a failed snapshot reconciliation', (
    tester,
  ) async {
    await tester.runAsync(() => db.connectionStateDao.read());
    final events = StreamController<VpnStatus>.broadcast(sync: true);
    final plan = _plan('a');
    var reads = 0;
    final coordinator = ConnectionCoordinator(
      database: db,
      statusEvents: events.stream,
      needsStatusPolling: () => false,
      inspect: (_) async => HostConnection(VpnStatus.connected, plan: plan),
      inspectObserved: (_, _) async => throw StateError('Snapshot unavailable'),
      readTraffic: (_) async => _traffic(plan, ++reads),
    );
    addTearDown(coordinator.dispose);
    addTearDown(events.close);
    final initialized = coordinator.initialize(registerReferences: false);
    await tester.pump();
    await initialized;
    coordinator.setTrafficVisible(true);
    await tester.pump();
    expect(reads, 1);
    events.add(VpnStatus.disconnected);
    await tester.pump();
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect(coordinator.state.value.plan, isNull);
    expect(coordinator.state.value.traffic!.uplink, 100);
    expect(coordinator.state.value.metricsAvailable, false);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 1);
  });

  for (final fail in [false, true]) {
    test(
      'offline runtime save revokes replay and restores it only on rollback; fail=$fail',
      () async {
        final old = _plan('a', platform: ConnectionPlatform.windows);
        await _seed(db, old);
        final before = await db.connectionStateDao.read();
        var replayAllowed = true;
        var revokes = 0;
        var restores = 0;
        final coordinator = await _initialize(
          ConnectionCoordinator(
            database: db,
            inspect: (_) async => const HostConnection(VpnStatus.disconnected),
            revokeReplay: (plan) async {
              expect(plan!.id, old.id);
              revokes++;
              replayAllowed = false;
              return () async {
                restores++;
                replayAllowed = true;
              };
            },
            resetTraffic: _noReset,
          ),
        );
        final next = ConnectionConfiguration(
          connection: ConnectionSettings(expert: true),
        );
        final operation = coordinator.apply(
          next,
          writeAssets: () async {
            expect(replayAllowed, false);
            await _writeAsset(db);
            if (fail) throw StateError('Asset write failed');
          },
        );
        if (fail) {
          await expectLater(operation, throwsStateError);
          expect(
            (await db.connectionStateDao.read()).toJson(),
            before.toJson(),
          );
          expect(await db.select(db.coreConfig).get(), isEmpty);
        } else {
          await operation;
          expect((await coordinator.configuration).encode(), next.encode());
          expect(await db.select(db.coreConfig).get(), hasLength(1));
        }
        expect(revokes, 1);
        expect(restores, fail ? 1 : 0);
        expect(replayAllowed, fail);
      },
    );
  }

  test(
    'unchanged and non-runtime saves do not revoke a confirmed plan',
    () async {
      final old = _plan('a', platform: ConnectionPlatform.windows);
      await _seed(db, old);
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          inspect: (_) async => const HostConnection(VpnStatus.disconnected),
          revokeReplay: (_) async =>
              throw StateError('Unexpected replay revocation'),
          resetTraffic: _noReset,
        ),
      );
      await coordinator.apply(old.configuration);
      await coordinator.apply(
        old.configuration,
        affectsRuntime: false,
        writeAssets: () => _writeAsset(db),
      );
      expect(await db.select(db.coreConfig).get(), hasLength(1));
    },
  );

  for (final failAtStart in [false, true]) {
    test(
      'a failed attempt without an old running plan revokes only that stopped attempt; start=$failAtStart',
      () async {
        final old = _plan('a', platform: ConnectionPlatform.windows);
        final next = _plan(
          'b',
          platform: ConnectionPlatform.windows,
          entryIds: [2],
        );
        await _seed(db, old);
        final before = await db.connectionStateDao.read();
        var host = const HostConnection(VpnStatus.disconnected);
        final calls = <String>[];
        final coordinator = await _initialize(
          ConnectionCoordinator(
            database: db,
            prepare: (_, _) async => next,
            inspect: (_) async => host,
            start: (plan) async {
              calls.add('start:${plan.id}');
              host = HostConnection(VpnStatus.connected, plan: plan);
              if (failAtStart) throw StateError('Start failed');
              return host;
            },
            stop: (_) async {
              calls.add('stop');
              return host = const HostConnection(VpnStatus.disconnected);
            },
            revokeReplay: (plan) async {
              expect(host.status, VpnStatus.disconnected);
              calls.add('revoke:${plan!.id}');
              return null;
            },
            resetTraffic: _noReset,
          ),
        );
        await expectLater(
          coordinator.apply(
            next.configuration,
            connect: true,
            writeAssets: () async {
              throw StateError('Commit failed');
            },
          ),
          throwsStateError,
        );
        expect(calls, ['start:${next.id}', 'stop', 'revoke:${next.id}']);
        expect((await db.connectionStateDao.read()).toJson(), before.toJson());
        expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
      },
    );
  }

  test(
    'failure restores an old running plan without revoking its replay',
    () async {
      final old = _plan('a', platform: ConnectionPlatform.windows);
      final next = _plan(
        'b',
        platform: ConnectionPlatform.windows,
        entryIds: [2],
      );
      await _seed(db, old);
      var host = HostConnection(VpnStatus.connected, plan: old);
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          prepare: (_, _) async => next,
          inspect: (_) async => host,
          start: (plan) async =>
              host = HostConnection(VpnStatus.connected, plan: plan),
          stop: (_) async =>
              host = const HostConnection(VpnStatus.disconnected),
          revokeReplay: (_) async =>
              throw StateError('Unexpected replay revocation'),
          resetTraffic: _noReset,
        ),
      );
      await expectLater(
        coordinator.apply(
          next.configuration,
          writeAssets: () async {
            throw StateError('Commit failed');
          },
        ),
        throwsStateError,
      );
      expect(host.plan!.id, old.id);
      expect(coordinator.state.value.phase, ConnectionPhase.connected);
    },
  );

  test(
    'reopen cleans a stopped uncommitted plan when there is no old session',
    () async {
      final next = _plan('b', platform: ConnectionPlatform.windows);
      await db.connectionStateDao.beginApply(
        0,
        jsonEncode({'attemptId': next.id, 'old': null, 'next': next.encode()}),
      );
      final revoked = <String>[];
      await _initialize(
        ConnectionCoordinator(
          database: db,
          inspect: (_) async => const HostConnection(VpnStatus.disconnected),
          revokeReplay: (plan) async {
            revoked.add(plan!.id);
            return null;
          },
          resetTraffic: _noReset,
        ),
      );
      expect(revoked, [next.id]);
      expect((await db.connectionStateDao.read()).pendingApplyJson, isNull);
    },
  );

  test(
    'failed replay cleanup retains the pending journal for a later retry',
    () async {
      final next = _plan('b', platform: ConnectionPlatform.windows);
      final pending = jsonEncode({
        'attemptId': next.id,
        'old': null,
        'next': next.encode(),
      });
      await db.connectionStateDao.beginApply(0, pending);
      final coordinator = ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        revokeReplay: (_) async =>
            throw StateError('Replay file is unavailable'),
        resetTraffic: _noReset,
      );
      addTearDown(coordinator.dispose);
      await expectLater(
        coordinator.initialize(poll: false, registerReferences: false),
        throwsStateError,
      );
      expect((await db.connectionStateDao.read()).pendingApplyJson, pending);
      expect(coordinator.state.value.phase, ConnectionPhase.failed);
      expect(coordinator.state.value.issue, 'restoreFailed');
    },
  );

  test('a queued draft cannot reconnect without prior authorization', () async {
    final ready = Completer<void>();
    final release = Completer<void>();
    final plan = _plan('a');
    var host = const HostConnection(VpnStatus.disconnected);
    var prepared = 0;
    var writes = 0;
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        prepare: (_, _) async {
          prepared++;
          return plan;
        },
        start: (_) async {
          ready.complete();
          await release.future;
          return host = HostConnection(VpnStatus.connected, plan: plan);
        },
        stop: (_) async => throw StateError('Must not stop the active plan'),
        inspect: (_) async => host,
        resetTraffic: _noReset,
      ),
    );
    final connect = coordinator.apply(plan.configuration, connect: true);
    await ready.future;
    final queued = expectLater(
      coordinator.apply(
        plan.configuration,
        allowReconnect: false,
        writeAssets: () async {
          writes++;
        },
      ),
      throwsA(
        isA<ConnectionHostException>().having(
          (error) => error.reason,
          'reason',
          'reconnectRequired',
        ),
      ),
    );
    release.complete();
    await connect;
    await queued;
    expect(prepared, 1);
    expect(writes, 0);
    expect(coordinator.state.value.plan!.id, plan.id);
  });

  test('a stale editor cannot overwrite newer saved configuration', () async {
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        resetTraffic: _noReset,
      ),
    );
    final old = (await coordinator.configuration).encode();
    final next = ConnectionConfiguration(
      connection: ConnectionSettings(expert: true),
    );
    await coordinator.apply(next, affectsRuntime: false);
    await expectLater(
      coordinator.apply(
        ConnectionConfiguration(),
        affectsRuntime: false,
        expectedConfiguration: old,
      ),
      throwsA(
        isA<ConnectionHostException>().having(
          (error) => error.reason,
          'reason',
          'configurationChanged',
        ),
      ),
    );
    expect((await coordinator.configuration).encode(), next.encode());
  });

  for (final fail in [false, true]) {
    test(
      'stop-only apply commits safely or restores the old session; fail=$fail',
      () async {
        final plan = _plan('old', platform: ConnectionPlatform.windows);
        await _seed(db, plan);
        var host = HostConnection(VpnStatus.connected, plan: plan);
        var starts = 0;
        var replayAllowed = true;
        final coordinator = await _initialize(
          ConnectionCoordinator(
            database: db,
            prepare: (_, _) async =>
                throw StateError('Stop-only must not prepare'),
            start: (old) async {
              expect(replayAllowed, true);
              starts++;
              return host = HostConnection(VpnStatus.connected, plan: old);
            },
            stop: (_) async =>
                host = const HostConnection(VpnStatus.disconnected),
            inspect: (_) async => host,
            revokeReplay: (old) async {
              expect(old!.id, plan.id);
              expect(host.status, VpnStatus.disconnected);
              replayAllowed = false;
              return () async {
                replayAllowed = true;
              };
            },
            resetTraffic: _noReset,
          ),
        );
        final next = ConnectionConfiguration(
          connection: ConnectionSettings(expert: true),
        );
        final operation = coordinator.apply(
          next,
          disconnect: true,
          affectsRuntime: false,
          writeAssets: () async {
            expect(replayAllowed, false);
            await _writeAsset(db);
            if (fail) throw StateError('Disk write failed');
          },
        );
        if (fail) {
          await expectLater(operation, throwsStateError);
          expect(host.plan!.id, plan.id);
          expect(
            (await coordinator.configuration).encode(),
            plan.configuration.encode(),
          );
          expect(await db.select(db.coreConfig).get(), isEmpty);
        } else {
          await operation;
          expect(host.status, VpnStatus.disconnected);
          expect((await coordinator.configuration).encode(), next.encode());
          expect(await db.select(db.coreConfig).get(), hasLength(1));
        }
        expect(starts, fail ? 1 : 0);
        expect(replayAllowed, fail);
        expect((await db.connectionStateDao.read()).pendingApplyJson, isNull);
      },
    );
  }

  test(
    'settings and assets commit once, only after the host confirms the plan',
    () async {
      final next = _plan('b', entryIds: [2]);
      final enteredStart = Completer<void>();
      final confirmation = Completer<HostConnection>();
      var host = const HostConnection(VpnStatus.disconnected);
      var writes = 0;
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          prepare: (_, _) async => next,
          start: (_) async {
            enteredStart.complete();
            host = await confirmation.future;
            return host;
          },
          stop: (_) async => throw StateError('Unexpected stop'),
          inspect: (_) async => host,
          resetTraffic: _noReset,
        ),
      );
      final before = await db.connectionStateDao.read();
      final applying = coordinator.apply(
        next.configuration,
        connect: true,
        writeAssets: () async {
          expect(host.connected, true);
          writes++;
          await _writeAsset(db);
        },
      );
      await enteredStart.future;
      final waiting = await db.connectionStateDao.read();
      expect(waiting.revision, before.revision);
      expect(waiting.settingsJson, before.settingsJson);
      expect(waiting.confirmedSnapshotJson, isNull);
      expect(waiting.pendingApplyJson, isNotNull);
      expect(writes, 0);
      expect(await db.select(db.coreConfig).get(), isEmpty);

      confirmation.complete(HostConnection(VpnStatus.connected, plan: next));
      await applying;
      final saved = await db.connectionStateDao.read();
      expect(saved.revision, before.revision + 1);
      expect(saved.settingsJson, next.configuration.encode());
      expect(saved.confirmedSnapshotJson, next.encode());
      expect(saved.pendingApplyJson, isNull);
      expect(writes, 1);
      expect(await db.select(db.coreConfig).get(), hasLength(1));
      expect(coordinator.state.value.phase, ConnectionPhase.connected);
      expect(coordinator.state.value.plan!.id, next.id);
    },
  );

  test(
    'preparation failure never stops the old session or changes saved data',
    () async {
      final old = _plan('a');
      final next = _plan('b', entryIds: [2]);
      await _seed(db, old);
      final before = await db.connectionStateDao.read();
      final calls = <String>[];
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          prepare: (_, _) async => throw StateError('Preparation failed'),
          start: (_) async {
            calls.add('start');
            throw StateError('Unexpected start');
          },
          stop: (_) async {
            calls.add('stop');
            return const HostConnection(VpnStatus.disconnected);
          },
          inspect: (_) async => HostConnection(VpnStatus.connected, plan: old),
          resetTraffic: _noReset,
        ),
      );
      await expectLater(
        coordinator.apply(next.configuration),
        throwsStateError,
      );
      expect(calls, isEmpty);
      expect((await db.connectionStateDao.read()).toJson(), before.toJson());
      expect(coordinator.state.value.phase, ConnectionPhase.connected);
      expect(coordinator.state.value.plan!.encode(), old.encode());
    },
  );

  test('failed new startup stops its partial session and restores the old snapshot', () async {
    final old = _plan('a');
    final next = _plan('b', entryIds: [2]);
    await _seed(db, old);
    final before = await db.connectionStateDao.read();
    var host = HostConnection(VpnStatus.connected, plan: old);
    final calls = <String>[];
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        prepare: (_, _) async => next,
        start: (plan) async {
          calls.add('start:${plan.id}');
          if (plan.id == next.id) {
            host = HostConnection(VpnStatus.connecting, plan: plan);
            throw const ConnectionHostException('startFailed');
          }
          expect(plan.encode(), old.encode());
          return host = HostConnection(VpnStatus.connected, plan: plan);
        },
        stop: (plan) async {
          calls.add('stop:${plan?.id}');
          return host = const HostConnection(VpnStatus.disconnected);
        },
        inspect: (_) async => host,
        resetTraffic: _noReset,
      ),
    );
    await expectLater(
      coordinator.apply(next.configuration),
      throwsA(isA<ConnectionHostException>()),
    );
    expect(calls, [
      'stop:${old.id}',
      'start:${next.id}',
      'stop:${next.id}',
      'start:${old.id}',
    ]);
    expect((await db.connectionStateDao.read()).toJson(), before.toJson());
    expect(coordinator.state.value.phase, ConnectionPhase.connected);
    expect(coordinator.state.value.plan!.id, old.id);
    expect(coordinator.state.value.issue, 'startFailed');
  });

  test(
    'asset write failure rolls back both database writes and the running plan',
    () async {
      final old = _plan('a');
      final next = _plan('b', entryIds: [2]);
      await _seed(db, old);
      final before = await db.connectionStateDao.read();
      var host = HostConnection(VpnStatus.connected, plan: old);
      final calls = <String>[];
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          prepare: (_, _) async => next,
          start: (plan) async {
            calls.add('start:${plan.id}');
            return host = HostConnection(VpnStatus.connected, plan: plan);
          },
          stop: (plan) async {
            calls.add('stop:${plan?.id}');
            return host = const HostConnection(VpnStatus.disconnected);
          },
          inspect: (_) async => host,
          resetTraffic: _noReset,
        ),
      );
      await expectLater(
        coordinator.apply(
          next.configuration,
          writeAssets: () async {
            await _writeAsset(db);
            throw StateError('Asset write failed');
          },
        ),
        throwsStateError,
      );
      expect(calls, [
        'stop:${old.id}',
        'start:${next.id}',
        'stop:${next.id}',
        'start:${old.id}',
      ]);
      expect(await db.select(db.coreConfig).get(), isEmpty);
      expect((await db.connectionStateDao.read()).toJson(), before.toJson());
      expect(coordinator.state.value.plan!.id, old.id);
      expect(coordinator.state.value.phase, ConnectionPhase.connected);
    },
  );

  test('a cancelled late startup callback cannot commit and restores the old session', () async {
    final old = _plan('a');
    final next = _plan('b', entryIds: [2]);
    await _seed(db, old);
    final before = await db.connectionStateDao.read();
    var host = HostConnection(VpnStatus.connected, plan: old);
    final enteredStart = Completer<void>();
    final releaseStart = Completer<void>();
    var writes = 0;
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        prepare: (_, _) async => next,
        start: (plan) async {
          if (plan.id == next.id) {
            enteredStart.complete();
            await releaseStart.future;
          }
          return host = HostConnection(VpnStatus.connected, plan: plan);
        },
        stop: (_) async => host = const HostConnection(VpnStatus.disconnected),
        inspect: (_) async => host,
        resetTraffic: _noReset,
      ),
    );
    final applying = coordinator.apply(
      next.configuration,
      writeAssets: () async {
        writes++;
      },
    );
    final failed = expectLater(
      applying,
      throwsA(isA<ConnectionHostException>()),
    );
    await enteredStart.future;
    coordinator.cancel();
    releaseStart.complete();
    await failed;
    expect(writes, 0);
    expect((await db.connectionStateDao.read()).toJson(), before.toJson());
    expect(coordinator.state.value.phase, ConnectionPhase.connected);
    expect(coordinator.state.value.plan!.id, old.id);
    expect(coordinator.state.value.issue, 'cancelled');
  });

  test('failed compensating stops preserve the journal and a later command recovers', () async {
    final old = _plan('a');
    final next = _plan('b', entryIds: [2]);
    await _seed(db, old);
    final before = await db.connectionStateDao.read();
    var host = HostConnection(VpnStatus.connected, plan: old);
    var rejectNextStop = true;
    var rejectOldRestore = true;
    var rejectOldCleanup = true;
    final permission = PlatformPermissionResult(
      kind: PlatformPermissionKind.androidVpn,
      state: PlatformPermissionState.denied,
    );
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        prepare: (_, _) async => next,
        start: (plan) async {
          host = HostConnection(VpnStatus.connected, plan: plan);
          if (plan.id == old.id && rejectOldRestore) {
            host = HostConnection(VpnStatus.connecting, plan: plan);
            throw const ConnectionHostException('startFailed');
          }
          return host;
        },
        stop: (plan) async {
          if ((plan?.id == next.id && rejectNextStop) ||
              (plan?.id == old.id && !host.connected && rejectOldCleanup)) {
            throw const ConnectionHostException('stopFailed');
          }
          return host = const HostConnection(VpnStatus.disconnected);
        },
        inspect: (_) async => host,
        resetTraffic: _noReset,
      ),
    );
    await expectLater(
      coordinator.apply(
        next.configuration,
        writeAssets: () async {
          await _writeAsset(db);
          throw ConnectionHostException('changeFailed', permission: permission);
        },
      ),
      throwsA(isA<ConnectionHostException>()),
    );
    final pending = (await db.connectionStateDao.read()).pendingApplyJson;
    expect(pending, isNotNull);
    expect(host.plan!.id, next.id); // The draft really is still running.
    expect(coordinator.state.value.phase, ConnectionPhase.failed);
    expect(coordinator.state.value.busy, false);
    expect(coordinator.state.value.issue, 'restoreFailed');
    expect(coordinator.state.value.permission, same(permission));
    expect(coordinator.state.value.plan, isNull); // It was never committed.
    expect((await coordinator.configuration).encode(), before.settingsJson);
    expect(await db.select(db.coreConfig).get(), isEmpty);
    expect((await coordinator.readReferences()).protectedIds, {1, 2});

    rejectNextStop = false;
    await expectLater(
      coordinator.disconnect(),
      throwsA(isA<ConnectionHostException>()),
    );
    final failedRecovery = await db.connectionStateDao.read();
    expect(failedRecovery.pendingApplyJson, pending);
    expect(failedRecovery.revision, before.revision);
    expect(failedRecovery.settingsJson, before.settingsJson);
    expect(failedRecovery.confirmedSnapshotJson, before.confirmedSnapshotJson);
    expect(coordinator.state.value.phase, ConnectionPhase.failed);
    expect(coordinator.state.value.busy, false);
    expect(coordinator.state.value.issue, 'restoreFailed');

    rejectOldRestore = false;
    rejectOldCleanup = false;
    await coordinator.disconnect();
    expect((await db.connectionStateDao.read()).toJson(), before.toJson());
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect(coordinator.state.value.issue, isNull);
  });

  test('failed maintenance stop with unreadable host is retryable without changing saved state', () async {
    final old = _plan('a');
    await _seed(db, old);
    final before = await db.connectionStateDao.read();
    var host = HostConnection(VpnStatus.connected, plan: old);
    var rejectStop = true;
    var rejectInspect = false;
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        prepare: (_, _) async => throw StateError('Unexpected preparation'),
        start: (_) async => throw StateError('Unexpected start'),
        stop: (_) async {
          if (rejectStop) {
            rejectInspect = true;
            throw const ConnectionHostException('stopFailed');
          }
          return host = const HostConnection(VpnStatus.disconnected);
        },
        inspect: (_) async {
          if (rejectInspect) {
            throw const ConnectionHostException('runtimeUnavailable');
          }
          return host;
        },
        resetTraffic: _noReset,
      ),
    );
    await expectLater(
      coordinator.stopForMaintenance(),
      throwsA(isA<ConnectionHostException>()),
    );
    expect(coordinator.state.value.phase, ConnectionPhase.failed);
    expect(coordinator.state.value.busy, false);
    expect(coordinator.state.value.issue, 'stopFailed');
    expect(coordinator.state.value.plan, isNull);
    expect((await db.connectionStateDao.read()).toJson(), before.toJson());

    rejectStop = false;
    rejectInspect = false;
    await coordinator.disconnect();
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect((await db.connectionStateDao.read()).toJson(), before.toJson());
  });

  test(
    'cancellation during a late asset callback rolls back its transaction',
    () async {
      final old = _plan('a');
      final next = _plan('b', entryIds: [2]);
      await _seed(db, old);
      final before = await db.connectionStateDao.read();
      var host = HostConnection(VpnStatus.connected, plan: old);
      final enteredWrite = Completer<void>();
      final releaseWrite = Completer<void>();
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          prepare: (_, _) async => next,
          start: (plan) async =>
              host = HostConnection(VpnStatus.connected, plan: plan),
          stop: (_) async =>
              host = const HostConnection(VpnStatus.disconnected),
          inspect: (_) async => host,
          resetTraffic: _noReset,
        ),
      );
      final applying = coordinator.apply(
        next.configuration,
        writeAssets: () async {
          await _writeAsset(db);
          enteredWrite.complete();
          await releaseWrite.future;
        },
      );
      final failed = expectLater(
        applying,
        throwsA(isA<ConnectionHostException>()),
      );
      await enteredWrite.future;
      coordinator.cancel();
      releaseWrite.complete();
      await failed;
      expect(await db.select(db.coreConfig).get(), isEmpty);
      expect((await db.connectionStateDao.read()).toJson(), before.toJson());
      expect(coordinator.state.value.phase, ConnectionPhase.connected);
      expect(coordinator.state.value.plan!.id, old.id);
      expect(coordinator.state.value.issue, 'cancelled');
    },
  );

  test('reopen with an uncommitted running new plan restores the old plan, not the draft', () async {
    final old = _plan('a');
    final next = _plan('b', entryIds: [2]);
    await _seed(db, old);
    final before = await db.connectionStateDao.read();
    await db.connectionStateDao.beginApply(
      before.revision,
      jsonEncode({
        'attemptId': next.id,
        'old': old.encode(),
        'next': next.encode(),
      }),
    );
    var host = HostConnection(VpnStatus.connected, plan: next);
    final calls = <String>[];
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        prepare: (_, _) async =>
            throw StateError('Recovery must use the saved snapshot'),
        start: (plan) async {
          calls.add('start:${plan.id}');
          expect(plan.encode(), old.encode());
          return host = HostConnection(VpnStatus.connected, plan: plan);
        },
        stop: (plan) async {
          calls.add('stop:${plan?.id}');
          return host = const HostConnection(VpnStatus.disconnected);
        },
        inspect: (known) async {
          expect(known.map((plan) => plan.id).toSet(), {old.id, next.id});
          return host;
        },
        resetTraffic: _noReset,
      ),
    );
    expect(calls, ['stop:${next.id}', 'start:${old.id}']);
    expect((await db.connectionStateDao.read()).toJson(), before.toJson());
    expect(coordinator.state.value.phase, ConnectionPhase.connected);
    expect(coordinator.state.value.plan!.id, old.id);
    expect(coordinator.state.value.issue, 'previousSettingsRestored');
  });

  test(
    'when both new startup and old restoration fail the UI is disconnected',
    () async {
      final old = _plan('a');
      final next = _plan('b', entryIds: [2]);
      await _seed(db, old);
      final before = await db.connectionStateDao.read();
      var host = HostConnection(VpnStatus.connected, plan: old);
      final calls = <String>[];
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          prepare: (_, _) async => next,
          start: (plan) async {
            calls.add('start:${plan.id}');
            host = HostConnection(VpnStatus.connecting, plan: plan);
            throw const ConnectionHostException('startFailed');
          },
          stop: (plan) async {
            calls.add('stop:${plan?.id}');
            return host = const HostConnection(VpnStatus.disconnected);
          },
          inspect: (_) async => host,
          resetTraffic: _noReset,
        ),
      );
      await expectLater(
        coordinator.apply(next.configuration),
        throwsA(isA<ConnectionHostException>()),
      );
      expect(calls, [
        'stop:${old.id}',
        'start:${next.id}',
        'stop:${next.id}',
        'start:${old.id}',
        'stop:${old.id}',
      ]);
      expect((await db.connectionStateDao.read()).toJson(), before.toJson());
      expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
      expect(coordinator.state.value.plan, isNull);
      expect(coordinator.state.value.metricsAvailable, false);
      expect(coordinator.state.value.issue, 'restoreFailed');
    },
  );

  test('subscription protection includes every runtime and pending entry/exit plus saved selections', () async {
    final old = _plan('a', entryIds: [11, 12, 13], exitId: 14);
    final stored = ConnectionConfiguration(
      connection: ConnectionSettings(
        selection: const ServerSelection.server(21),
        smart: SmartRoutingSettings(finalExitId: 22),
      ),
    );
    await _seed(db, old, configuration: stored);
    final next = _plan('b', entryIds: [31, 32, 33], exitId: 34);
    var host = HostConnection(VpnStatus.connected, plan: old);
    final enteredStop = Completer<void>();
    final releaseStop = Completer<void>();
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        prepare: (_, _) async => next,
        start: (plan) async =>
            host = HostConnection(VpnStatus.connected, plan: plan),
        stop: (plan) async {
          if (plan?.id == old.id) {
            enteredStop.complete();
            await releaseStop.future;
          }
          return host = const HostConnection(VpnStatus.disconnected);
        },
        inspect: (_) async => host,
        resetTraffic: _noReset,
      ),
    );
    final initial = await coordinator.readReferences();
    expect(initial.runningIds, {11, 12, 13, 14});
    expect(initial.fixedId, 21);
    expect(initial.finalExitId, 22);
    expect(initial.protectedIds, {11, 12, 13, 14, 21, 22});

    final applying = coordinator.apply(next.configuration);
    final failed = expectLater(
      applying,
      throwsA(isA<ConnectionHostException>()),
    );
    await enteredStop.future;
    final pending = await coordinator.readReferences();
    expect(pending.runningIds, {11, 12, 13, 14, 31, 32, 33, 34});
    expect(pending.protectedIds, {11, 12, 13, 14, 21, 22, 31, 32, 33, 34});
    coordinator.cancel();
    releaseStop.complete();
    await failed;
    expect((await coordinator.readReferences()).protectedIds, {
      11,
      12,
      13,
      14,
      21,
      22,
    });
  });
  test('App-only reset preserves connection and committed settings', () async {
    final plan = _plan('a');
    await _seed(db, plan);
    final traffic = RuntimeSnapshot(
      sessionId: 'session',
      planId: plan.id,
      startedAtMs: 1,
      endedAtMs: 0,
      uplink: 10,
      downlink: 20,
      totalUplink: 110,
      totalDownlink: 220,
      available: true,
      sampledAtMs: 2,
      savedAtMs: 2,
      error: '',
    );
    var resets = 0;
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async =>
            HostConnection(VpnStatus.connected, plan: plan, traffic: traffic),
        start: (_) async => throw StateError('Reset must not start VPN'),
        stop: (_) async => throw StateError('Reset must not stop VPN'),
        resetTraffic: (current) async {
          expect(current?.id, plan.id);
          resets++;
          return null;
        },
      ),
    );
    final before = await db.connectionStateDao.read();
    await coordinator.resetTraffic();
    expect(resets, 1);
    expect(coordinator.state.value.phase, ConnectionPhase.connected);
    expect(coordinator.state.value.plan?.id, plan.id);
    expect(coordinator.state.value.traffic?.uplink, 10);
    expect(coordinator.state.value.traffic?.downlink, 20);
    expect(coordinator.state.value.traffic?.totalUplink, 0);
    expect(coordinator.state.value.traffic?.totalDownlink, 0);
    expect((await db.connectionStateDao.read()).toJson(), before.toJson());
  });

  test('repeated Start does not reconnect an already running host', () async {
    final plan = _plan('a');
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => HostConnection(VpnStatus.connected, plan: plan),
        start: (_) async => throw StateError('Start must be idempotent'),
        prepare: (_, _) async => throw StateError('Do not prepare again'),
        resetTraffic: _noReset,
      ),
    );
    await Future.wait([coordinator.connect(), coordinator.connect()]);
    expect(coordinator.state.value.plan?.id, plan.id);
    expect((await db.connectionStateDao.read()).revision, 0);
  });

  test('permission failure survives status reconciliation and clears after a successful retry', () async {
    final plan = _plan('b');
    var host = const HostConnection(VpnStatus.disconnected);
    var granted = false;
    final permission = PlatformPermissionResult(
      kind: PlatformPermissionKind.androidVpn,
      state: PlatformPermissionState.denied,
    );
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        prepare: (_, _) async => plan,
        inspect: (_) async => host,
        start: (_) async {
          if (!granted) {
            throw ConnectionHostException(
              'permissionRequired',
              permission: permission,
            );
          }
          return host = HostConnection(VpnStatus.connected, plan: plan);
        },
        stop: (_) async => host = const HostConnection(VpnStatus.disconnected),
        resetTraffic: _noReset,
      ),
    );
    await expectLater(
      coordinator.connect(),
      throwsA(isA<ConnectionHostException>()),
    );
    await coordinator.refresh();
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect(coordinator.state.value.failed, isTrue);
    expect(coordinator.state.value.permission, permission);
    granted = true;
    await coordinator.connect();
    expect(coordinator.state.value.phase, ConnectionPhase.connected);
    expect(coordinator.state.value.issue, isNull);
    expect(coordinator.state.value.permission, isNull);
  });

  test(
    'explicit status queries pause in background and resume in foreground',
    () async {
      var reads = 0;
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          inspect: (_) async {
            reads++;
            return const HostConnection(VpnStatus.disconnected);
          },
          resetTraffic: _noReset,
        ),
      );
      final before = reads;
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      await coordinator.refresh();
      expect(reads, before);
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await coordinator.refresh();
      expect(reads, before + 1);
    },
  );
}

Future<ConnectionCoordinator> _initialize(
  ConnectionCoordinator coordinator,
) async {
  addTearDown(coordinator.dispose);
  await coordinator.initialize(poll: false, registerReferences: false);
  return coordinator;
}

Future<RuntimeSnapshot?> _noReset(ConnectionPlan? _) async =>
    throw StateError('Unexpected runtime reset');

RuntimeSnapshot _traffic(ConnectionPlan plan, int sample) => RuntimeSnapshot(
  sessionId: 'session',
  planId: plan.id,
  startedAtMs: 1,
  endedAtMs: 0,
  uplink: sample * 100,
  downlink: sample * 200,
  available: true,
  sampledAtMs: sample * 1000,
  savedAtMs: 1,
  error: '',
);

Future<void> _seed(
  AppDatabase db,
  ConnectionPlan plan, {
  ConnectionConfiguration? configuration,
}) => db.connectionStateDao.commit(
  baseRevision: 0,
  settingsJson: (configuration ?? plan.configuration).encode(),
  confirmedSnapshotJson: plan.encode(),
);

Future<void> _writeAsset(AppDatabase db) async {
  await db
      .into(db.coreConfig)
      .insert(
        CoreConfigCompanion.insert(
          name: 'Asset',
          type: 'outbound',
          tags: '',
          data: Value(
            base64Encode(utf8.encode('{"protocol":"freedom","tag":"Asset"}')),
          ),
          delay: 0,
          subId: 0,
        ),
      );
}

ConnectionPlan _plan(
  String digit, {
  List<int> entryIds = const [1],
  int? exitId,
  ConnectionPlatform platform = ConnectionPlatform.android,
}) {
  final id = List.filled(32, digit).join();
  final configuration = ConnectionConfiguration(
    connection: ConnectionSettings(
      selection: entryIds.length == 1
          ? ServerSelection.server(entryIds.single)
          : const ServerSelection.automatic(),
      smart: SmartRoutingSettings(
        entryCount: entryIds.length,
        finalExitId: exitId,
      ),
    ),
  );
  ServerSnapshot server(int id) => ServerSnapshot(
    id: id,
    sourceId: 7,
    outbound: {'protocol': 'freedom', 'tag': 'server-$id'},
  );
  final entries = entryIds.map(server).toList();
  final finalExit = exitId == null ? null : server(exitId);
  final xrayJson = jsonEncode({
    'outbounds': [
      for (final entry in entries) entry.outbound,
      if (finalExit != null) finalExit.outbound,
    ],
  });
  final compiled = CompiledConnection(
    xrayJson: xrayJson,
    settingsJson: jsonEncode(configuration.connection.toJson()),
    entries: entries,
    finalExit: finalExit,
    nodeTags: {
      for (final entry in [...entries, ?finalExit]) entry.name: entry.id,
    },
    ruleTags: {},
    assetDirectory: '/fixture/assets',
  );
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(
      xrayJson,
      runtime: ManagedRuntimeRequest(
        statePath: '/fixture/run/runtime.json',
        planId: id,
      ),
    ).toJson(),
  );
  return ConnectionPlan.create(
    id: id,
    configuration: configuration,
    compiled: compiled,
    platform: platform,
    request: StartVpnRequest(
      configuration.policy.toTun(ConnectionPlatform.android),
      null,
      '18002',
      XrayInboundAccount('fixture', 'fixture'),
      '18003',
      jsonEncode(invoke.toJson()),
    ),
  );
}
