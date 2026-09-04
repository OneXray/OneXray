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
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/routing/custom_editor.dart';
import 'package:onexray/service/routing/custom_service.dart';
import 'package:onexray/service/routing/state.dart';

RoutingProfileState _state(
  String name, {
  int entries = 1,
  RoutingRuleAction action = RoutingRuleAction.direct,
}) => RoutingProfileState(
  name: name,
  entryCount: entries,
  rules: [
    RoutingRuleState(
      ruleTag: 'Example',
      domain: const ['domain:example.com'],
      action: action,
    ),
  ],
);

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('new templates save without servers or activation; names and three-item cap are enforced', () async {
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        start: (_) async => throw StateError('Unexpected start'),
        stop: () async => throw StateError('Unexpected stop'),
      ),
    );
    final service = CustomRoutingEditorService(
      database: db,
      coordinator: coordinator,
    );
    final before = (await coordinator.configuration).encode();
    final id = await service.save(
      CustomRoutingEditorDraft(state: _state('  Work  ', entries: 3)),
      confirmReconnect: () async => throw StateError('Unexpected confirmation'),
    );
    final row = (await db.routingProfileDao.searchRow(id!))!;
    expect(row.name, 'Work');
    final json = jsonDecode(utf8.decode(base64Decode(row.data))) as Map;
    expect(json.containsKey('name'), false);
    expect(json.containsKey('geodata'), false);
    expect(CustomRoutingService.read(row).entryCount, 3);
    expect((json['routing'] as Map)['rules'], [
      {
        'ruleTag': 'Example',
        'domain': ['domain:example.com'],
        'outboundTag': 'direct',
      },
    ]);
    expect((await coordinator.configuration).encode(), before);
    await expectLater(
      service.save(
        CustomRoutingEditorDraft(state: _state('work')),
        confirmReconnect: () async => false,
      ),
      throwsA(
        isA<CustomRoutingEditorException>().having(
          (e) => e.reason,
          'reason',
          'duplicate',
        ),
      ),
    );
    for (final name in ['Two', 'Three']) {
      await service.save(
        CustomRoutingEditorDraft(state: _state(name)),
        confirmReconnect: () async => false,
      );
    }
    await expectLater(
      service.save(
        CustomRoutingEditorDraft(state: _state('Four')),
        confirmReconnect: () async => false,
      ),
      throwsA(
        isA<CustomRoutingEditorException>().having(
          (e) => e.reason,
          'reason',
          'limit',
        ),
      ),
    );
    expect(await service.rows, hasLength(3));
  });

  test(
    'active edit failure keeps the asset and does not restore the runtime',
    () async {
      final id = await CustomRoutingService(db).save(_state('Work'));
      final configuration = ConnectionConfiguration(
        connection: ConnectionSettings(
          trafficMode: TrafficMode.custom,
          customId: id,
        ),
      );
      final old = _runtime('a', configuration);
      await db.connectionConfigDao.commit(
        configurationJson: configuration.encode(),
      );
      var host = HostConnection(VpnStatus.connected, runtime: old);
      final calls = <String>[];
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          inspect: (_) async => host,
          start: (runtime) async {
            calls.add('start:${runtime.identity[0]}');
            throw const ConnectionHostException('startFailed');
          },
          stop: () async {
            calls.add('stop');
            return host = const HostConnection(VpnStatus.disconnected);
          },
        ),
      );
      final service = CustomRoutingEditorService(
        database: db,
        coordinator: coordinator,
        prepare: (next, _, _) async => _runtime('b', next),
      );
      final initial = await service.load(id);
      await service.save(
        CustomRoutingEditorDraft(
          original: initial.original,
          state: initial.state.copyWith(name: 'Renamed'),
        ),
        confirmReconnect: () async =>
            throw StateError('Rename must not reconnect'),
      );
      expect(calls, isEmpty);
      final renamed = await service.load(id);
      final changed = CustomRoutingEditorDraft(
        original: renamed.original,
        state: _state(renamed.state.name, entries: 2),
      );
      expect(
        await service.save(changed, confirmReconnect: () async => false),
        isNull,
      );
      expect(calls, isEmpty);
      final before = (await db.connectionConfigDao.read()).toJson();
      await expectLater(
        service.save(changed, confirmReconnect: () async => true),
        throwsA(isA<ConnectionHostException>()),
      );
      expect(
        (await db.routingProfileDao.searchRow(id))!.data,
        renamed.original!.data,
      );
      expect((await db.connectionConfigDao.read()).toJson(), before);
      expect(calls, ['stop', 'start:b', 'stop']);
      expect(coordinator.state.value.phase, ConnectionPhase.failed);
      expect(coordinator.state.value.runtime, isNull);
    },
  );

  test('active delete confirms and reconnects with Smart routing', () async {
    final id = await CustomRoutingService(db).save(_state('Work'));
    final configuration = ConnectionConfiguration(
      connection: ConnectionSettings(
        trafficMode: TrafficMode.custom,
        customId: id,
      ),
    );
    final old = _runtime('a', configuration);
    await db.connectionConfigDao.commit(
      configurationJson: configuration.encode(),
    );
    var host = HostConnection(VpnStatus.connected, runtime: old);
    final calls = <String>[];
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => host,
        prepare: (next, _) async => _runtime('b', next),
        start: (runtime) async {
          calls.add('start:${runtime.identity[0]}');
          return host = HostConnection(VpnStatus.connected, runtime: runtime);
        },
        stop: () async {
          calls.add('stop');
          return host = const HostConnection(VpnStatus.disconnected);
        },
      ),
    );
    final service = CustomRoutingEditorService(
      database: db,
      coordinator: coordinator,
    );
    final original = (await service.load(id)).original!;
    expect(
      await service.delete(
        original,
        confirm: (selected, reconnect) async {
          expect(selected, true);
          expect(reconnect, true);
          return true;
        },
      ),
      true,
    );
    expect(await db.routingProfileDao.searchRow(id), isNull);
    expect(calls, ['stop', 'start:b']);
    expect(
      (await coordinator.configuration).connection.trafficMode,
      TrafficMode.smart,
    );
    expect(
      coordinator.state.value.runtime!.configuration.connection.trafficMode,
      TrafficMode.smart,
    );
  });

  test(
    'unselected edits and stale drafts do not overwrite newer assets',
    () async {
      final id = await CustomRoutingService(db).save(_state('Work'));
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          inspect: (_) async => const HostConnection(VpnStatus.disconnected),
          start: (_) async => throw StateError('Unexpected start'),
          stop: () async => throw StateError('Unexpected stop'),
        ),
      );
      final service = CustomRoutingEditorService(
        database: db,
        coordinator: coordinator,
      );
      final original = await service.load(id);
      await service.save(
        CustomRoutingEditorDraft(
          original: original.original,
          state: _state('New name', entries: 2),
        ),
        confirmReconnect: () async =>
            throw StateError('Unexpected confirmation'),
      );
      await expectLater(
        service.save(original, confirmReconnect: () async => false),
        throwsA(isA<CustomRoutingEditorException>()),
      );
      expect((await db.routingProfileDao.searchRow(id))!.name, 'New name');
      expect(
        (await coordinator.configuration).connection.trafficMode,
        TrafficMode.smart,
      );
    },
  );

  test('failed Custom database save rolls staged Geodata back', () async {
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
      ),
    );
    final service = CustomRoutingEditorService(
      database: db,
      coordinator: coordinator,
    );
    await db.customStatement('''
      CREATE TRIGGER fail_custom_save BEFORE INSERT ON routing_profile
      BEGIN SELECT RAISE(FAIL, 'fixture'); END
    ''');
    final lifecycle = <String>[];
    final geodata = GeoDataImportDraft(
      const [],
      () async => lifecycle.add('commit'),
      () async {},
      publish: () async => lifecycle.add('publish'),
      complete: () async => lifecycle.add('complete'),
      rollback: () async => lifecycle.add('rollback'),
    );

    await expectLater(
      service.save(
        CustomRoutingEditorDraft(state: _state('Work')),
        confirmReconnect: () async => false,
        geodata: geodata,
      ),
      throwsA(anything),
    );

    expect(lifecycle, ['publish', 'commit', 'rollback']);
    expect(await db.routingProfileDao.allRows, isEmpty);
  });
}

Future<ConnectionCoordinator> _initialize(
  ConnectionCoordinator coordinator,
) async {
  addTearDown(coordinator.dispose);
  await coordinator.initialize(poll: false, registerReferences: false);
  return coordinator;
}

ConnectionRuntime _runtime(
  String digit,
  ConnectionConfiguration configuration,
) {
  final id = List.filled(32, digit).join();
  const text = '{"outbounds":[{"protocol":"freedom"}]}';
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(
      text,
      runtime: ManagedRuntimeRequest(
        statePath: '/fixture/run/runtime.json',
        token: id,
      ),
    ).toJson(),
  );
  return ConnectionRuntime.create(
    configuration: configuration,
    compiled: CompiledConnection(
      xrayJson: text,
      entries: [],
      finalExit: null,
      nodeTags: {},
      ruleTags: {},
    ),
    platform: ConnectionPlatform.android,
    request: StartVpnRequest(
      configuration.policy.toTun(ConnectionPlatform.android),
      null,
      '18003',
      jsonEncode(invoke.toJson()),
    ),
  );
}
