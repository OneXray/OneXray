import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

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
    'preparation failure leaves an untouched running connection active',
    () async {
      final old = _runtime('a');
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async => old,
          inspect: (_) async =>
              HostConnection(VpnStatus.connected, runtime: old),
          prepare: (_, _) async => throw const FormatException('bad input'),
          stop: () async => throw StateError('must not stop'),
        ),
      );

      await expectLater(
        coordinator.apply(ConnectionConfiguration(), allowReconnect: true),
        throwsFormatException,
      );

      expect(coordinator.state.value.phase, ConnectionPhase.connected);
      expect(coordinator.state.value.runtime?.identity, old.identity);
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
    ruleTags: const {},
  );
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(
      xrayJson,
      runtime: ManagedRuntimeRequest(
        statePath: '/fixture/run/runtime.json',
        listen: '127.0.0.1:18004',
        token: List.filled(32, digit).join(),
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
