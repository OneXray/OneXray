import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/connect/compiler.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/runtime_host.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/connect/routing/region_catalog.dart';
import 'package:onexray/service/connect/routing/smart/editor.dart';

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
  test(
    'Smart keeps legacy defaults and reconnects only for effective DNS changes',
    () {
      expect(SmartRoutingSettings.fromJson({}).directDnsAddress, '8.8.8.8');
      for (final enabled in [false, true]) {
        final before = SmartRoutingSettings(
          directDns: enabled,
          directDnsAddress: '1.1.1.1',
        );
        final after = SmartRoutingSettings.fromJson({
          ...before.toJson(),
          'directDnsAddress': '9.9.9.9',
        });
        expect(after.directDnsAddress, '9.9.9.9');
        expect(
          SmartRoutingEditorService.sameRuntime(
            ConnectionSettings(smart: before),
            after,
            _regions(),
          ),
          !enabled,
        );
      }
    },
  );

  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test(
    'Smart validates an edited DNS address with libXray before saving',
    () async {
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        ),
      );
      final original = await coordinator.configuration;
      var coreError = 'Invalid DNS address';
      var calls = 0;
      final service = SmartRoutingEditorService(
        database: db,
        coordinator: coordinator,
        loadRegions: () async => _regions(),
        testXray: (text) async {
          calls++;
          final json = jsonDecode(text);
          expect(json['dns']['servers'].last['tag'], 'app-dns-direct');
          expect(json['dns']['servers'].last['address'], '1.1.1.1');
          expect(json.containsKey('inbounds'), false);
          return coreError;
        },
      );
      Future<bool> save() => service.save(
        original: original,
        smart: SmartRoutingSettings(directDnsAddress: ' 1.1.1.1 '),
        confirmReconnect: () async => throw StateError('Must not reconnect'),
      );
      await expectLater(
        save(),
        throwsA(isA<AppFailure>().having((e) => e.cause, 'cause', coreError)),
      );
      expect((await coordinator.configuration).encode(), original.encode());
      coreError = '';
      expect(await save(), true);
      expect(
        (await coordinator.configuration).connection.smart.directDnsAddress,
        '1.1.1.1',
      );
      expect(calls, 2);
    },
  );

  test('unselected Smart saves without activation or servers; stale settings are rejected', () async {
    final original = ConnectionConfiguration(
      connection: ConnectionSettings(
        expert: true,
        rawId: 9,
        trafficMode: TrafficMode.custom,
        customId: 7,
      ),
    );
    await db.connectionConfigDao.commit(configurationJson: original.encode());
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        start: (_) async => throw StateError('Unexpected start'),
        stop: () async => throw StateError('Unexpected stop'),
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
      directWindows: true,
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
    'active save cancels without writes and failed reconnect is not restored',
    () async {
      final original = ConnectionConfiguration();
      final old = _runtime('a', original);
      await db.connectionConfigDao.commit(configurationJson: original.encode());
      var host = HostConnection(VpnStatus.connected, runtime: old);
      final calls = <String>[];
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          inspect: (_) async => host,
          prepare: (next, _) async => _runtime('b', next),
          start: (runtime) async {
            calls.add(
              runtime.identity == old.identity ? 'start:old' : 'start:new',
            );
            throw const ConnectionHostException('startFailed');
          },
          stop: () async {
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
      final before = (await db.connectionConfigDao.read()).toJson();
      await expectLater(
        service.save(
          original: original,
          smart: smart,
          confirmReconnect: () async => true,
        ),
        throwsA(isA<ConnectionHostException>()),
      );
      expect((await db.connectionConfigDao.read()).toJson(), before);
      expect(calls, ['stop', 'start:new', 'stop']);
      expect(coordinator.state.value.phase, ConnectionPhase.failed);
      expect(coordinator.state.value.runtime, isNull);
    },
  );

  test('a connection that appears after refresh cannot bypass reconnect confirmation', () async {
    final original = ConnectionConfiguration();
    final old = _runtime('a', original);
    var host = const HostConnection(VpnStatus.disconnected);
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => host,
        prepare: (_, _) async => throw StateError('Must not prepare'),
        start: (_) async => throw StateError('Must not start'),
        stop: () async => throw StateError('Must not stop'),
      ),
    );
    final service = SmartRoutingEditorService(
      database: db,
      coordinator: coordinator,
      loadRegions: () async {
        host = HostConnection(VpnStatus.connected, runtime: old);
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
    expect(host.runtime?.identity, old.identity);
  });

  test('Smart preview shares native rules and ignores non-semantic region/count changes', () {
    final regions = _regions();
    final smart = SmartRoutingSettings(
      directRegions: ['RU', 'CN'],
      blockAds: true,
    );
    final rules = ConnectionCompiler.smartRules(smart, regions);
    expect(rules.map((rule) => rule.ruleTag), [
      'app-smart-ads',
      'app-smart-direct-domain',
      'app-smart-direct-ip',
    ]);
    expect(rules[0].outboundTag, 'block');
    expect(rules[1].toJson(), {
      'ruleTag': 'app-smart-direct-domain',
      'domain': [
        'geosite:PRIVATE',
        'geosite:APPLE',
        'geosite:MICROSOFT',
        'geosite:BING',
        'geosite:CATEGORY-RU',
        'geosite:CN',
      ],
      'outboundTag': 'direct',
    });
    expect(rules[2].toJson(), {
      'ruleTag': 'app-smart-direct-ip',
      'ip': ['geoip:PRIVATE', 'geoip:RU', 'geoip:CN'],
      'outboundTag': 'direct',
    });
    expect(regions.regionCodes, ['CN', 'RU']);
    final original = ConnectionSettings(
      selection: const ServerSelection.server(8),
      smart: smart,
    );
    expect(
      SmartRoutingEditorService.sameRuntime(
        original,
        SmartRoutingSettings.fromJson({
          ...smart.toJson(),
          'directWindows': false,
        }),
        regions,
      ),
      false,
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
  });
}

Future<ConnectionCoordinator> _initialize(
  ConnectionCoordinator coordinator,
) async {
  addTearDown(coordinator.dispose);
  await coordinator.initialize(observe: false, registerReferences: false);
  return coordinator;
}

ConnectionRuntime _runtime(
  String digit,
  ConnectionConfiguration configuration,
) {
  const text = '{"outbounds":[{"protocol":"freedom"}]}';
  return ConnectionRuntime.create(
    configuration: configuration,
    compiled: CompiledConnection(
      xrayJson: text,
      validationJson: '{}',
      entries: [],
      finalExit: null,
      nodeTags: {},
    ),
    platform: ConnectionPlatform.android,
    request: StartVpnRequest(
      configuration.policy.toTun(ConnectionPlatform.android),
      null,
      '18003',
      jsonEncode(
        LibXrayInvokeRequest(
          method: LibXrayMethod.runXray,
          payload: RunXrayRequest(text).toJson(),
        ).toJson(),
      ),
    ),
  );
}
