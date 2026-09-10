import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connect/compiler.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/runtime_host.dart';
import 'package:onexray/service/connect/settings.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('a failed connection with retained runtime can still be stopped', () {
    expect(
      ConnectionView(
        phase: ConnectionPhase.failed,
        runtime: _runtime('a'),
      ).canDisconnect,
      isTrue,
    );
    expect(
      const ConnectionView(phase: ConnectionPhase.failed).canDisconnect,
      isFalse,
    );
    expect(
      const ConnectionView(
        phase: ConnectionPhase.failed,
        issue: 'stopFailed',
      ).canDisconnect,
      isTrue,
    );
  });

  test(
    'each reconciliation reads start metadata once and reuses that value',
    () async {
      final runtime = _runtime('a');
      final host = ConnectionRuntimeHost(
        readStatus: () async => VpnStatus.connected,
      );
      var reads = 0;
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async {
            reads++;
            return runtime;
          },
          inspect: host.inspect,
        ),
      );
      expect(reads, 1);
      expect(coordinator.state.value.runtime, same(runtime));
      await coordinator.refresh();
      expect(reads, 2);
      expect(coordinator.state.value.runtime, same(runtime));
    },
  );

  test('initialization trusts native disconnected status', () async {
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
      ),
    );

    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect(coordinator.state.value.runtime, isNull);
  });

  test(
    'metrics samples follow page visibility and reset the speed baseline',
    () async {
      final runtime = _runtime('a');
      var status = VpnStatus.connected;
      var reads = 0;
      var failing = false;
      var sample = const ConnectionTraffic(
        uplink: 100,
        downlink: 200,
        sampledAtMs: 1000,
      );
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async => runtime,
          inspect: (_) async => HostConnection(status, runtime: runtime),
          readTraffic: (_) async {
            reads++;
            if (failing) throw const FormatException('Unavailable metrics');
            return sample;
          },
        ),
      );
      expect(reads, 0);
      coordinator.setTrafficVisible(true);
      await Future<void>.delayed(Duration.zero);
      expect(reads, 1);
      expect(coordinator.state.value.traffic, sample);
      expect(coordinator.state.value.uploadSpeed, 0);

      sample = const ConnectionTraffic(
        uplink: 300,
        downlink: 700,
        sampledAtMs: 2000,
      );
      await coordinator.refreshTraffic();
      expect(coordinator.state.value.uploadSpeed, 200);
      expect(coordinator.state.value.downloadSpeed, 500);
      await coordinator.refresh();
      expect(coordinator.state.value.uploadSpeed, 200);

      coordinator.setTrafficVisible(false);
      final hiddenReads = reads;
      await coordinator.refreshTraffic();
      expect(reads, hiddenReads);
      sample = const ConnectionTraffic(
        uplink: 9000,
        downlink: 10000,
        sampledAtMs: 90000,
      );
      coordinator.setTrafficVisible(true);
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.state.value.traffic, sample);
      expect(coordinator.state.value.uploadSpeed, 0);

      failing = true;
      await coordinator.refreshTraffic();
      expect(coordinator.state.value.phase, ConnectionPhase.connected);
      expect(coordinator.state.value.issue, isNull);
      expect(coordinator.state.value.traffic, sample);
      expect(coordinator.state.value.metricsAvailable, isFalse);
      failing = false;
      sample = const ConnectionTraffic(
        uplink: 9500,
        downlink: 10500,
        sampledAtMs: 91000,
      );
      await coordinator.refreshTraffic();
      expect(coordinator.state.value.uploadSpeed, 0);

      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      final backgroundReads = reads;
      await coordinator.refreshTraffic();
      expect(reads, backgroundReads);
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.state.value.uploadSpeed, 0);
      status = VpnStatus.disconnected;
      await coordinator.refresh();
      expect(coordinator.state.value.traffic, isNull);
      expect(coordinator.state.value.metricsAvailable, isFalse);
    },
  );

  test(
    'read-only status and metrics do not enter the paused command queue',
    () async {
      final runtime = _runtime('a');
      var status = VpnStatus.connected;
      var reads = 0;
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async => runtime,
          inspect: (_) async => HostConnection(status, runtime: runtime),
          readTraffic: (_) async {
            reads++;
            return const ConnectionTraffic(
              uplink: 10,
              downlink: 20,
              sampledAtMs: 1000,
            );
          },
        ),
      );
      coordinator.setTrafficVisible(true);
      await Future<void>.delayed(Duration.zero);
      final before = reads;
      await coordinator.pauseForDataClear();
      try {
        await coordinator.refreshTraffic();
        expect(reads, before + 1);
        status = VpnStatus.disconnected;
        await coordinator.refresh();
        expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
        expect(coordinator.state.value.issue, isNull);
      } finally {
        coordinator.resumeAfterDataClear();
      }
    },
  );

  test('clear-data stop ignores late status and metrics responses', () async {
    final runtime = _runtime('a');
    final traffic = Completer<ConnectionTraffic>();
    final statusReply = Completer<HostConnection>();
    var holdStatus = false;
    var host = HostConnection(VpnStatus.connected, runtime: runtime);
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => runtime,
        inspect: (_) => holdStatus ? statusReply.future : Future.value(host),
        readTraffic: (_) => traffic.future,
        stop: () async => host = const HostConnection(VpnStatus.disconnected),
      ),
    );
    coordinator.setTrafficVisible(true);
    await Future<void>.delayed(Duration.zero);
    holdStatus = true;
    final refresh = coordinator.refresh();
    await Future<void>.delayed(Duration.zero);
    holdStatus = false;
    await coordinator.pauseForDataClear();
    await coordinator.stopForMaintenance();
    coordinator.resumeAfterDataClear();
    traffic.complete(
      const ConnectionTraffic(uplink: 10, downlink: 20, sampledAtMs: 1000),
    );
    statusReply.complete(HostConnection(VpnStatus.connected, runtime: runtime));
    await refresh;
    await Future<void>.delayed(Duration.zero);
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect(coordinator.state.value.traffic, isNull);
    expect(coordinator.state.value.runtime, isNull);
  });

  test('maintenance delegates simulator stops to the native host', () async {
    var stopCalls = 0;
    var statusFails = false;
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async {
          if (statusFails) {
            throw const ConnectionHostException('nativeStatusFailed');
          }
          return HostConnection(
            VpnStatus.disconnected,
            permission: PlatformPermissionResult(
              kind: PlatformPermissionKind.appleVpn,
              state: PlatformPermissionState.notRequired,
            ),
          );
        },
        stop: ConnectionRuntimeHost(
          readStatus: () async => VpnStatus.disconnected,
          stopVpn: () async {
            stopCalls++;
            return NativeVpnCommandResult(state: NativeVpnCommandState.success);
          },
        ).stop,
      ),
    );

    await coordinator.stopForMaintenance();
    await coordinator.stopForMaintenance();

    expect(stopCalls, 2);
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect(coordinator.state.value.issue, isNull);

    statusFails = true;
    await expectLater(
      coordinator.stopForMaintenance(),
      throwsA(isA<ConnectionHostException>()),
    );
    expect(coordinator.state.value.phase, ConnectionPhase.failed);

    statusFails = false;
    await coordinator.stopForMaintenance();

    expect(stopCalls, 3);
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect(coordinator.state.value.issue, isNull);
  });

  for (final permission in [
    null,
    for (final state in PlatformPermissionState.values)
      if (state != PlatformPermissionState.notRequired)
        PlatformPermissionResult(
          kind: PlatformPermissionKind.appleVpn,
          state: state,
        ),
    PlatformPermissionResult(
      kind: PlatformPermissionKind.androidVpn,
      state: PlatformPermissionState.notRequired,
    ),
  ]) {
    test(
      'maintenance still stops a normal idle host (${permission?.kind.name}/${permission?.state.name})',
      () async {
        var stopCalls = 0;
        final coordinator = await _initialize(
          ConnectionCoordinator(
            database: db,
            readRuntime: () async => null,
            inspect: (_) async =>
                HostConnection(VpnStatus.disconnected, permission: permission),
            stop: () async {
              stopCalls++;
              return const HostConnection(VpnStatus.disconnected);
            },
          ),
        );

        await coordinator.stopForMaintenance();

        expect(stopCalls, 1);
        expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
      },
    );
  }

  test('maintenance never ignores a running Debug core stop failure', () async {
    var stopCalls = 0;
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async => HostConnection(
          VpnStatus.connected,
          runtime: _runtime('a'),
          permission: PlatformPermissionResult(
            kind: PlatformPermissionKind.appleVpn,
            state: PlatformPermissionState.notRequired,
          ),
        ),
        stop: () async {
          stopCalls++;
          throw const ConnectionHostException('stopFailed');
        },
      ),
    );

    await expectLater(
      coordinator.stopForMaintenance(),
      throwsA(isA<ConnectionHostException>()),
    );

    expect(stopCalls, 1);
    expect(coordinator.state.value.phase, ConnectionPhase.failed);
    expect(coordinator.state.value.runtime, isNotNull);
    expect(coordinator.state.value.issue, 'stopFailed');
  });

  test('initialization exposes a missing platform permission', () async {
    final permission = PlatformPermissionResult(
      kind: PlatformPermissionKind.androidVpn,
      state: PlatformPermissionState.denied,
    );
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async =>
            HostConnection(VpnStatus.disconnected, permission: permission),
      ),
    );

    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    expect(coordinator.state.value.issue, 'permissionRequired');
    expect(coordinator.state.value.permission, permission);
  });

  for (final kind in [
    PlatformPermissionKind.appleVpn,
    PlatformPermissionKind.macosSystemExtension,
    PlatformPermissionKind.androidVpn,
    PlatformPermissionKind.androidLocalNetwork,
  ]) {
    test('home initialization requests $kind before becoming ready', () async {
      var permission = PlatformPermissionResult(
        kind: kind,
        state: PlatformPermissionState.notDetermined,
      );
      final calls = <String>[];
      final coordinator = ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async {
          calls.add('read');
          return HostConnection(VpnStatus.disconnected, permission: permission);
        },
        prepare: (_, _) async => fail('Authorization must not prepare nodes'),
        start: (_) async => fail('Authorization must not start VPN'),
        stop: () async => fail('Authorization must not stop VPN'),
      );
      addTearDown(coordinator.dispose);

      final requested = Completer<void>();
      final permissionReply = Completer<PlatformPermissionResult>();
      Future<PlatformPermissionResult> request() {
        calls.add('request');
        requested.complete();
        return permissionReply.future;
      }

      final first = coordinator.initialize(
        poll: false,
        registerReferences: false,
        requestPermission: request,
      );
      final second = coordinator.initialize(
        poll: false,
        registerReferences: false,
        requestPermission: request,
      );
      var ready = false;
      final initialization = Future.wait([first, second]).then((_) {
        ready = true;
      });
      await requested.future.timeout(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['read', 'request']);
      expect(ready, isFalse);

      permission = PlatformPermissionResult(
        kind: kind,
        state: PlatformPermissionState.granted,
      );
      permissionReply.complete(permission);
      await initialization;

      expect(calls, ['read', 'request', 'read']);
      expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
      expect(coordinator.state.value.issue, isNull);
      expect(coordinator.state.value.permission, isNull);
    });
  }

  test(
    'home permission denial allows entry without repeated prompts',
    () async {
      var permission = PlatformPermissionResult(
        kind: PlatformPermissionKind.appleVpn,
        state: PlatformPermissionState.notDetermined,
      );
      var requests = 0;
      final coordinator = ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async =>
            HostConnection(VpnStatus.disconnected, permission: permission),
      );
      addTearDown(coordinator.dispose);

      Future<PlatformPermissionResult> request() async {
        requests++;
        permission = PlatformPermissionResult(
          kind: PlatformPermissionKind.appleVpn,
          state: PlatformPermissionState.denied,
        );
        return permission;
      }

      await coordinator.initialize(
        poll: false,
        registerReferences: false,
        requestPermission: request,
      );
      expect(requests, 1);
      expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
      expect(coordinator.state.value.issue, 'permissionRequired');
      expect(
        coordinator.state.value.permission?.state,
        PlatformPermissionState.denied,
      );

      await coordinator.initialize(
        poll: false,
        registerReferences: false,
        requestPermission: request,
      );
      await coordinator.refresh();
      expect(requests, 1);
      expect(coordinator.state.value.issue, 'permissionRequired');

      permission = PlatformPermissionResult(
        kind: PlatformPermissionKind.appleVpn,
        state: PlatformPermissionState.granted,
      );
      await coordinator.refresh();
      expect(requests, 1);
      expect(coordinator.state.value.issue, isNull);
    },
  );

  for (final permission in <PlatformPermissionResult?>[
    null,
    PlatformPermissionResult(
      kind: PlatformPermissionKind.appleVpn,
      state: PlatformPermissionState.granted,
    ),
    PlatformPermissionResult(
      kind: PlatformPermissionKind.appleVpn,
      state: PlatformPermissionState.notRequired,
    ),
  ]) {
    test('home initialization skips permission ${permission?.state}', () async {
      var reads = 0;
      final coordinator = ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async {
          reads++;
          return HostConnection(VpnStatus.disconnected, permission: permission);
        },
      );
      addTearDown(coordinator.dispose);

      await coordinator.initialize(
        poll: false,
        registerReferences: false,
        requestPermission: () async => fail('Permission is already satisfied'),
      );
      expect(reads, 1);
      expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
      expect(coordinator.state.value.issue, isNull);
    });
  }

  test(
    'startup and foreground refresh track local network permission',
    () async {
      var permission = PlatformPermissionResult(
        kind: PlatformPermissionKind.androidLocalNetwork,
        state: PlatformPermissionState.notDetermined,
      );
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async => null,
          inspect: (_) async =>
              HostConnection(VpnStatus.disconnected, permission: permission),
        ),
      );
      expect(coordinator.state.value.issue, 'permissionRequired');
      expect(
        coordinator.state.value.permission?.kind,
        PlatformPermissionKind.androidLocalNetwork,
      );

      permission = PlatformPermissionResult(
        kind: PlatformPermissionKind.androidVpn,
        state: PlatformPermissionState.granted,
      );
      await coordinator.refresh();
      expect(coordinator.state.value.issue, isNull);

      permission = PlatformPermissionResult(
        kind: PlatformPermissionKind.androidLocalNetwork,
        state: PlatformPermissionState.denied,
      );
      await coordinator.refresh();
      expect(coordinator.state.value.issue, 'permissionRequired');
      expect(
        coordinator.state.value.permission?.kind,
        PlatformPermissionKind.androidLocalNetwork,
      );
    },
  );

  test(
    'foreground reconciliation clears a resolved permission issue',
    () async {
      var permission = PlatformPermissionResult(
        kind: PlatformPermissionKind.androidVpn,
        state: PlatformPermissionState.denied,
      );
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async => null,
          inspect: (_) async =>
              HostConnection(VpnStatus.disconnected, permission: permission),
        ),
      );
      expect(coordinator.state.value.issue, 'permissionRequired');

      permission = PlatformPermissionResult(
        kind: PlatformPermissionKind.androidVpn,
        state: PlatformPermissionState.granted,
      );
      await coordinator.refresh();

      expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
      expect(coordinator.state.value.issue, isNull);
      expect(coordinator.state.value.permission, isNull);
    },
  );

  test('foreground reconciliation exposes a revoked permission', () async {
    var permission = PlatformPermissionResult(
      kind: PlatformPermissionKind.appleVpn,
      state: PlatformPermissionState.granted,
    );
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async =>
            HostConnection(VpnStatus.disconnected, permission: permission),
      ),
    );
    expect(coordinator.state.value.issue, isNull);

    permission = PlatformPermissionResult(
      kind: PlatformPermissionKind.appleVpn,
      state: PlatformPermissionState.denied,
    );
    await coordinator.refresh();

    expect(coordinator.state.value.issue, 'permissionRequired');
    expect(coordinator.state.value.permission, permission);
  });

  test('disconnected actions preserve a missing permission', () async {
    final permission = PlatformPermissionResult(
      kind: PlatformPermissionKind.androidVpn,
      state: PlatformPermissionState.denied,
    );
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async =>
            HostConnection(VpnStatus.disconnected, permission: permission),
      ),
    );

    await coordinator.apply(ConnectionConfiguration(), affectsRuntime: false);

    expect(coordinator.state.value.issue, 'permissionRequired');
    expect(coordinator.state.value.permission, permission);
  });

  test(
    'initialization does not report a platform error as missing permission',
    () async {
      final permission = PlatformPermissionResult(
        kind: PlatformPermissionKind.appleVpn,
        state: PlatformPermissionState.failed,
        message: 'load failed',
      );
      final coordinator = ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async => throw ConnectionHostException(
          'nativeStatusFailed',
          permission: permission,
        ),
      );
      addTearDown(coordinator.dispose);

      await expectLater(
        coordinator.initialize(poll: false, registerReferences: false),
        throwsA(isA<ConnectionHostException>()),
      );
      expect(coordinator.state.value.phase, ConnectionPhase.failed);
      expect(coordinator.state.value.issue, 'nativeStatusFailed');
      expect(coordinator.state.value.permission, permission);
    },
  );

  test(
    'a successful initialization retry clears its previous failure',
    () async {
      var fail = true;
      final coordinator = ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async {
          if (fail) {
            throw const ConnectionHostException('nativeStatusFailed');
          }
          return const HostConnection(VpnStatus.disconnected);
        },
      );
      addTearDown(coordinator.dispose);

      await expectLater(
        coordinator.initialize(poll: false, registerReferences: false),
        throwsA(isA<ConnectionHostException>()),
      );
      expect(coordinator.state.value.phase, ConnectionPhase.failed);

      fail = false;
      await coordinator.initialize(poll: false, registerReferences: false);

      expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
      expect(coordinator.state.value.issue, isNull);
    },
  );

  test('connect prepares, starts and commits selected settings', () async {
    final next = _runtime('b', entryIds: const [2]);
    var status = VpnStatus.disconnected;
    ConnectionRuntime? active;
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => active,
        inspect: (_) async => HostConnection(status, runtime: active),
        inspectObserved: (_, observed) async => HostConnection(
          observed,
          runtime: observed == VpnStatus.connected ? next : null,
        ),
        prepare: (_, _) async => next,
        start: (runtime) async {
          status = VpnStatus.connected;
          active = runtime;
          return HostConnection(status, runtime: runtime);
        },
        stop: () async {
          status = VpnStatus.disconnected;
          active = null;
          return HostConnection(status);
        },
      ),
    );

    await coordinator.apply(next.configuration, connect: true);

    expect(coordinator.state.value.phase, ConnectionPhase.connected);
    expect(coordinator.state.value.runtime?.identity, next.identity);
    expect(
      (await coordinator.configuration).encode(),
      next.configuration.encode(),
    );
  });

  test('reconnect validates and prepares only after stopping', () async {
    final old = _runtime('a');
    final next = _runtime('b', entryIds: const [2]);
    var host = HostConnection(VpnStatus.connected, runtime: old);
    final calls = <String>[];
    final phases = <ConnectionPhase>[];
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => host.runtime,
        inspect: (_) async => host,
        prepare: (_, _) async {
          calls.add('prepare');
          expect(host.status, VpnStatus.disconnected);
          return next;
        },
        stop: () async {
          calls.add('stop');
          host = const HostConnection(VpnStatus.disconnected);
          return host;
        },
        start: (runtime) async {
          calls.add('start');
          host = HostConnection(VpnStatus.connected, runtime: runtime);
          return host;
        },
      ),
    );
    coordinator.state.addListener(
      () => phases.add(coordinator.state.value.phase),
    );

    await coordinator.apply(
      next.configuration,
      validateAssets: () async {
        calls.add('validate');
        expect(host.status, VpnStatus.disconnected);
      },
    );

    expect(calls, ['stop', 'validate', 'prepare', 'start']);
    expect(phases, [
      ConnectionPhase.disconnecting,
      ConnectionPhase.preparing,
      ConnectionPhase.connecting,
      ConnectionPhase.connected,
    ]);
    expect(coordinator.state.value.runtime?.identity, next.identity);
    expect(
      (await coordinator.configuration).encode(),
      next.configuration.encode(),
    );
  });

  for (final stopThrows in [false, true]) {
    test('failed stop prevents all startup work: throws=$stopThrows', () async {
      final old = _runtime('a');
      final calls = <String>[];
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async => old,
          inspect: (_) async =>
              HostConnection(VpnStatus.connected, runtime: old),
          prepare: (_, _) async {
            calls.add('prepare');
            return _runtime('b');
          },
          stop: () async {
            if (stopThrows) throw const ConnectionHostException('stopFailed');
            return HostConnection(VpnStatus.connected, runtime: old);
          },
          start: (runtime) async {
            calls.add('start');
            return HostConnection(VpnStatus.connected, runtime: runtime);
          },
        ),
      );

      await expectLater(
        coordinator.apply(
          ConnectionConfiguration(),
          validateAssets: () async {
            calls.add('validate');
          },
        ),
        throwsA(isA<ConnectionHostException>()),
      );

      expect(calls, isEmpty);
      expect(coordinator.state.value.phase, ConnectionPhase.failed);
      expect(coordinator.state.value.runtime?.identity, old.identity);
    });
  }

  test('preparation validation failure never starts the VPN host', () async {
    var starts = 0;
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => null,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        prepare: (_, _) async =>
            throw const FormatException('Xray configuration validation failed'),
        start: (_) async {
          starts++;
          throw StateError('must not start');
        },
      ),
    );

    await expectLater(
      coordinator.apply(ConnectionConfiguration(), connect: true),
      throwsFormatException,
    );

    expect(starts, 0);
  });

  test('active node IDs protect subscription replacement', () async {
    final active = _runtime('a', entryIds: const [2, 3], exitId: 4);
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readRuntime: () async => active,
        inspect: (_) async =>
            HostConnection(VpnStatus.connected, runtime: active),
      ),
    );

    expect((await coordinator.readReferences()).runningIds, {2, 3, 4});
  });

  test(
    'start failure stops the attempt and never restarts the old runtime',
    () async {
      final old = _runtime('a');
      final next = _runtime('b', entryIds: const [2]);
      var status = VpnStatus.connected;
      ConnectionRuntime? active = old;
      var starts = 0;
      var stops = 0;
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async => active,
          inspect: (_) async => HostConnection(status, runtime: active),
          inspectObserved: (_, observed) async => HostConnection(
            observed,
            runtime: observed == VpnStatus.connected ? next : null,
          ),
          prepare: (_, _) async => next,
          start: (_) async {
            starts++;
            throw const ConnectionHostException('startFailed');
          },
          stop: () async {
            stops++;
            status = VpnStatus.disconnected;
            active = null;
            return HostConnection(status);
          },
        ),
      );

      await expectLater(
        coordinator.apply(next.configuration, allowReconnect: true),
        throwsA(isA<ConnectionHostException>()),
      );

      expect(starts, 1);
      expect(stops, 2);
      expect(coordinator.state.value.phase, ConnectionPhase.failed);
      expect(coordinator.state.value.runtime, isNull);
      expect(
        (await coordinator.configuration).encode(),
        isNot(next.configuration.encode()),
      );

      await coordinator.refresh(observedStatus: VpnStatus.connected);

      expect(coordinator.state.value.phase, ConnectionPhase.failed);
      expect(coordinator.state.value.runtime?.identity, next.identity);
    },
  );

  test(
    'preparation failure after stopping does not restore the old connection',
    () async {
      final old = _runtime('a');
      var host = HostConnection(VpnStatus.connected, runtime: old);
      var starts = 0;
      var stops = 0;
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async => host.runtime,
          inspect: (_) async => host,
          prepare: (_, _) async {
            expect(host.status, VpnStatus.disconnected);
            throw const FormatException('bad input');
          },
          start: (_) async {
            starts++;
            throw StateError('must not start');
          },
          stop: () async {
            stops++;
            host = const HostConnection(VpnStatus.disconnected);
            return host;
          },
        ),
      );

      await expectLater(
        coordinator.apply(ConnectionConfiguration(), allowReconnect: true),
        throwsFormatException,
      );

      expect(coordinator.state.value.phase, ConnectionPhase.failed);
      expect(coordinator.state.value.runtime, isNull);
      expect(starts, 0);
      expect(stops, 2);
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

ConnectionRuntime _runtime(
  String digit, {
  List<int> entryIds = const [1],
  int? exitId,
}) {
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
  ResolvedServer server(int id) => ResolvedServer(
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
    entries: entries,
    finalExit: finalExit,
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
