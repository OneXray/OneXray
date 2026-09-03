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
import 'package:onexray/service/routing/region_catalog.dart';
import 'package:onexray/service/routing/smart_editor.dart';

RegionCatalog _regions() => RegionCatalog.fromJson(
  {
    'geosite': {
      'CN': ['CN'],
      'RU': ['CATEGORY-RU'],
    },
    'geoip': {
      'CN': ['CN'],
      'RU': ['RU'],
      'IR': ['IR'],
    },
  },
  geositeCodes: ['CN', 'CATEGORY-RU'],
  geoipCodes: ['CN', 'RU'],
);

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('unselected Smart saves without activation or servers; stale settings are rejected', () async {
    final original = ConnectionConfiguration(
      connection: ConnectionSettings(
        expert: true,
        rawId: 9,
        trafficMode: TrafficMode.custom,
        customId: 7,
      ),
    );
    await db.connectionStateDao.commit(
      baseRevision: 0,
      settingsJson: original.encode(),
      confirmedPlanId: null,
    );
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        start: (_) async => throw StateError('Unexpected start'),
        stop: (_) async => throw StateError('Unexpected stop'),
      ),
    );
    final service = SmartRoutingEditorService(
      database: db,
      coordinator: coordinator,
      loadRegions: () async => _regions(),
    );
    final smart = SmartRoutingSettings(
      entryCount: 3,
      directRegions: [],
      blockAds: true,
    );
    expect(
      await service.save(
        original: original,
        smart: smart,
        confirmReconnect: () async =>
            throw StateError('Unexpected confirmation'),
      ),
      true,
    );
    final saved = await coordinator.configuration;
    expect(saved.connection.expert, true);
    expect(saved.connection.rawId, 9);
    expect(saved.connection.trafficMode, TrafficMode.custom);
    expect(saved.connection.customId, 7);
    expect(saved.connection.smart.toJson(), smart.toJson());
    expect(saved.policy.toJson(), original.policy.toJson());
    await expectLater(
      service.save(
        original: original,
        smart: SmartRoutingSettings(),
        confirmReconnect: () async => false,
      ),
      throwsA(isA<ConnectionHostException>()),
    );
    expect((await coordinator.configuration).encode(), saved.encode());
  });

  test(
    'active save cancels without writes and compensates failed reconnect',
    () async {
      final original = ConnectionConfiguration();
      final old = _plan('a', original);
      await db.connectionStateDao.commit(
        baseRevision: 0,
        settingsJson: original.encode(),
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
      final service = SmartRoutingEditorService(
        database: db,
        coordinator: coordinator,
        loadRegions: () async => _regions(),
      );
      final smart = SmartRoutingSettings(blockAds: true);
      expect(
        await service.save(
          original: original,
          smart: smart,
          confirmReconnect: () async => false,
        ),
        false,
      );
      expect(calls, isEmpty);
      final before = (await db.connectionStateDao.read()).toJson();
      await expectLater(
        service.save(
          original: original,
          smart: smart,
          confirmReconnect: () async => true,
        ),
        throwsA(isA<ConnectionHostException>()),
      );
      expect((await db.connectionStateDao.read()).toJson(), before);
      expect(coordinator.state.value.plan!.id, old.id);
      fail = false;
      expect(
        await service.save(
          original: original,
          smart: smart,
          confirmReconnect: () async => true,
        ),
        true,
      );
      expect((await coordinator.configuration).connection.smart.blockAds, true);
      expect(coordinator.state.value.plan!.id, List.filled(32, 'b').join());
    },
  );

  test('a connection that appears after refresh cannot bypass reconnect confirmation', () async {
    final original = ConnectionConfiguration();
    final old = _plan('a', original);
    var host = const HostConnection(VpnStatus.disconnected);
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => host,
        prepare: (_, _) async => throw StateError('Must not prepare'),
        start: (_) async => throw StateError('Must not start'),
        stop: (_) async => throw StateError('Must not stop'),
      ),
    );
    final service = SmartRoutingEditorService(
      database: db,
      coordinator: coordinator,
      loadRegions: () async {
        host = HostConnection(VpnStatus.connected, plan: old);
        return _regions();
      },
    );
    await expectLater(
      service.save(
        original: original,
        smart: SmartRoutingSettings(blockAds: true),
        confirmReconnect: () async =>
            throw StateError('No earlier connected state'),
      ),
      throwsA(
        isA<ConnectionHostException>().having(
          (e) => e.reason,
          'reason',
          'reconnectRequired',
        ),
      ),
    );
    expect((await coordinator.configuration).encode(), original.encode());
    expect(host.plan!.id, old.id);
  });

  test('Smart preview shares native rules and ignores non-semantic region/count changes', () {
    final regions = _regions();
    final smart = SmartRoutingSettings(
      directRegions: ['RU', 'CN'],
      blockAds: true,
    );
    final rules = ConnectionCompiler.smartRules(smart, regions);
    expect(rules.map((rule) => rule['ruleTag']), [
      'app-smart-ads',
      'app-smart-private-domain',
      'app-smart-private-ip',
      'app-smart-apple',
      'app-smart-regions-domain',
      'app-smart-regions-ip',
    ]);
    expect(rules[4]['domain'], ['geosite:CATEGORY-RU', 'geosite:CN']);
    expect(rules[5]['ip'], ['geoip:RU', 'geoip:CN']);
    expect(regions.regionCodes, ['CN', 'RU']);
    final original = ConnectionSettings(
      selection: const ServerSelection.server(8),
      smart: smart,
    );
    expect(
      SmartRoutingEditorService.sameRuntime(
        original,
        SmartRoutingSettings(
          entryCount: 3,
          directRegions: ['CN', 'RU'],
          blockAds: true,
        ),
        regions,
      ),
      true,
    );
    expect(
      SmartRoutingEditorService.sameRuntime(
        original,
        SmartRoutingSettings(
          directRegions: ['CN', 'RU'],
          blockAds: true,
          directDns: false,
        ),
        regions,
      ),
      false,
    );
    expect(
      SmartRoutingEditorService.sameRuntime(
        original,
        SmartRoutingSettings(
          directRegions: ['CN', 'RU'],
          blockAds: true,
          resolveIpOnNoMatch: false,
        ),
        regions,
      ),
      false,
    );
  });
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
      jsonEncode(
        LibXrayInvokeRequest(
          method: LibXrayMethod.runXray,
          payload: RunXrayRequest(
            text,
            runtime: ManagedRuntimeRequest(
              statePath: '/fixture/run/runtime.json',
              planId: id,
            ),
          ).toJson(),
        ).toJson(),
      ),
    ),
  );
}
