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

  test('background pauses metrics polling and foreground can resume', () async {
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
  });
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
    platform: ConnectionPlatform.android,
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
