import 'dart:convert';

import 'package:drift/native.dart';
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
import 'package:onexray/service/routing/custom_editor.dart';
import 'package:onexray/service/routing/custom_service.dart';
import 'package:onexray/service/routing/custom_template.dart';

CustomRoutingTemplate _template({int entries = 1, String action = 'direct'}) =>
    CustomRoutingTemplate.parse(
      jsonEncode({
        'outbounds': [
          for (var i = 0; i < entries; i++) {},
          {'tag': 'direct', 'protocol': 'freedom'},
          {'tag': 'block', 'protocol': 'blackhole'},
        ],
        'routing': {
          'rules': [
            {
              'type': 'field',
              'ruleTag': 'Example',
              'domain': ['domain:example.com'],
              'outboundTag': action,
            },
          ],
        },
      }),
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
        stop: (_) async => throw StateError('Unexpected stop'),
      ),
    );
    final service = CustomRoutingEditorService(
      database: db,
      coordinator: coordinator,
    );
    final before = (await coordinator.configuration).encode();
    final id = await service.save(
      CustomRoutingEditorDraft(
        name: '  Work  ',
        template: _template(entries: 3),
      ),
      confirmReconnect: () async => throw StateError('Unexpected confirmation'),
    );
    final row = (await db.routingProfileDao.searchRow(id!))!;
    expect(row.name, 'Work');
    final json = jsonDecode(utf8.decode(base64Decode(row.data))) as Map;
    expect(json['name'], 'Work');
    expect(CustomRoutingService.read(row).entryCount, 3);
    expect((json['routing'] as Map)['rules'], [
      {
        'type': 'field',
        'ruleTag': 'Example',
        'domain': ['domain:example.com'],
        'outboundTag': 'direct',
      },
    ]);
    expect((await coordinator.configuration).encode(), before);
    await expectLater(
      service.save(
        CustomRoutingEditorDraft(name: 'work', template: _template()),
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
        CustomRoutingEditorDraft(name: name, template: _template()),
        confirmReconnect: () async => false,
      );
    }
    await expectLater(
      service.save(
        CustomRoutingEditorDraft(name: 'Four', template: _template()),
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

  test('active edit and delete confirm, compensate failure, and never publish an uncommitted template', () async {
    final id = await CustomRoutingService(db)
        .save(name: 'Work', text: _template().encode());
    final configuration = ConnectionConfiguration(
      connection: ConnectionSettings(
        trafficMode: TrafficMode.custom,
        customId: id,
      ),
    );
    final old = _plan('a', configuration);
    await db.connectionStateDao.commit(
      settingsJson: configuration.encode(),
      confirmedPlanId: old.id,
    );
    var host = HostConnection(VpnStatus.connected, plan: old);
    var fail = true;
    final calls = <String>[];
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        readPlan: (id) async => id == old.id ? old : null,
        inspect: (_) async => host,
        prepare: (next, _) async => _plan('b', next),
        start: (plan) async {
          calls.add('start:${plan.id[0]}');
          if (fail && plan.id != old.id) {
            throw const ConnectionHostException('startFailed');
          }
          return host = HostConnection(VpnStatus.connected, plan: plan);
        },
        stop: (_) async {
          calls.add('stop');
          return host = const HostConnection(VpnStatus.disconnected);
        },
      ),
    );
    final service = CustomRoutingEditorService(
      database: db,
      coordinator: coordinator,
      prepare: (next, _, _) async => _plan('b', next),
    );
    final initial = await service.load(id);
    await service.save(
      CustomRoutingEditorDraft(
        original: initial.original,
        name: 'Renamed',
        template: initial.template,
      ),
      confirmReconnect: () async =>
          throw StateError('Rename must not reconnect'),
    );
    expect(calls, isEmpty);
    final renamed = await service.load(id);
    final changed = CustomRoutingEditorDraft(
      original: renamed.original,
      name: renamed.name,
      template: _template(entries: 2),
    );
    expect(
      await service.save(changed, confirmReconnect: () async => false),
      isNull,
    );
    expect(calls, isEmpty);
    final before = (await db.connectionStateDao.read()).toJson();
    await expectLater(
      service.save(changed, confirmReconnect: () async => true),
      throwsA(isA<ConnectionHostException>()),
    );
    expect(
      (await db.routingProfileDao.searchRow(id))!.data,
      renamed.original!.data,
    );
    expect((await db.connectionStateDao.read()).toJson(), before);
    expect(coordinator.state.value.plan!.id, old.id);
    calls.clear();
    expect(
      await service.delete(
        renamed.original!,
        confirm: (selected, reconnect) async {
          expect(selected, true);
          expect(reconnect, true);
          return false;
        },
      ),
      false,
    );
    expect(calls, isEmpty);
    await expectLater(
      service.delete(renamed.original!, confirm: (_, _) async => true),
      throwsA(isA<ConnectionHostException>()),
    );
    expect(await db.routingProfileDao.searchRow(id), isNotNull);
    expect(
      (await coordinator.configuration).connection.trafficMode,
      TrafficMode.custom,
    );
    fail = false;
    expect(
      await service.delete(renamed.original!, confirm: (_, _) async => true),
      true,
    );
    expect(await db.routingProfileDao.searchRow(id), isNull);
    expect(
      (await coordinator.configuration).connection.trafficMode,
      TrafficMode.smart,
    );
    expect(
      coordinator.state.value.plan!.configuration.connection.trafficMode,
      TrafficMode.smart,
    );
  });

  test(
    'unselected edits and stale drafts do not overwrite newer assets',
    () async {
      final id = await CustomRoutingService(db)
          .save(name: 'Work', text: _template().encode());
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          inspect: (_) async => const HostConnection(VpnStatus.disconnected),
          start: (_) async => throw StateError('Unexpected start'),
          stop: (_) async => throw StateError('Unexpected stop'),
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
          name: 'New name',
          template: _template(entries: 2),
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
}

Future<ConnectionCoordinator> _initialize(
  ConnectionCoordinator coordinator,
) async {
  addTearDown(coordinator.dispose);
  await coordinator.initialize(poll: false, registerReferences: false);
  return coordinator;
}

ConnectionPlan _plan(String digit, ConnectionConfiguration configuration) {
  final id = List.filled(32, digit).join();
  const text = '{"outbounds":[{"protocol":"freedom"}]}';
  final invoke = LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(
      text,
      runtime: ManagedRuntimeRequest(
        statePath: '/fixture/run/runtime.json',
        planId: id,
      ),
    ).toJson(),
  );
  return ConnectionPlan.create(
    id: id,
    configuration: configuration,
    compiled: CompiledConnection(
      xrayJson: text,
      settingsJson: jsonEncode(configuration.connection.toJson()),
      entries: [],
      finalExit: null,
      nodeTags: {},
      ruleTags: {},
      assetDirectory: '/fixture/assets',
    ),
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
