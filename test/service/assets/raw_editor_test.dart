import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/assets/raw_editor.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';
import 'package:onexray/service/xray/raw/db.dart';

const _text =
    '{ "name": "original", "outbounds": [{"tag":"direct","protocol":"freedom"}] }';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('new Raw preserves exact source and existing normal selection without starting', () async {
    final configuration = ConnectionConfiguration(
      connection: ConnectionSettings(
        selection: const ServerSelection.server(77),
      ),
    );
    await db.connectionConfigDao.commit(
      configurationJson: configuration.encode(),
    );
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        start: (_) async => throw StateError('Unexpected start'),
        stop: () async => throw StateError('Unexpected stop'),
      ),
    );
    final service = RawEditorService(
      database: db,
      coordinator: coordinator,
      validate: (_) async => true,
    );
    final id = await service.save(
      const RawEditorDraft(name: 'original', text: _text),
      confirmReconnect: () async => throw StateError('Unexpected confirmation'),
    );
    expect(
      XrayRawDb.readFromDbData((await db.coreConfigDao.searchRow(id!))!),
      _text,
    );
    expect((await coordinator.configuration).encode(), configuration.encode());
    expect((await coordinator.configuration).connection.expert, false);
    expect(coordinator.state.value.phase, ConnectionPhase.disconnected);
    await db.coreConfigDao.insertAssetRow(
      XrayRawDb.configCompanion('two', _text),
    );
    await db.coreConfigDao.insertAssetRow(
      XrayRawDb.configCompanion('three', _text),
    );
    await expectLater(
      service.save(
        const RawEditorDraft(name: 'four', text: _text),
        confirmReconnect: () async => false,
      ),
      throwsA(isA<RawEditorException>()),
    );
    expect(await db.coreConfigDao.allRawRowsWithData, hasLength(3));
  });

  test('running Raw rename does not reconnect; cancel and failed start keep the asset', () async {
    final rawId = await db.coreConfigDao.insertAssetRow(
      XrayRawDb.configCompanion('original', _text),
    );
    final configuration = ConnectionConfiguration(
      connection: ConnectionSettings(expert: true, rawId: rawId),
    );
    final old = _runtime('a', configuration, _text);
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
          calls.add('start:${runtime.identity}');
          throw const ConnectionHostException('startFailed');
        },
        stop: () async {
          calls.add('stop');
          return host = const HostConnection(VpnStatus.disconnected);
        },
      ),
    );
    final service = RawEditorService(
      database: db,
      coordinator: coordinator,
      validate: (_) async => true,
      prepare: (configuration, _, text) async =>
          _runtime('b', configuration, text),
    );
    final original = await service.load(rawId);
    await service.save(
      RawEditorDraft(
        original: original.original,
        name: ' renamed ',
        text: original.text,
      ),
      confirmReconnect: () async => throw StateError('Rename must not confirm'),
    );
    expect(calls, isEmpty);
    expect((await db.coreConfigDao.searchRow(rawId))!.name, 'renamed');
    final renamed = await service.load(rawId);
    final changed = RawEditorDraft(
      original: renamed.original,
      name: renamed.name,
      text: renamed.text.replaceFirst('freedom', 'blackhole'),
    );
    final before = await db.connectionConfigDao.read();
    expect(
      await service.save(changed, confirmReconnect: () async => false),
      isNull,
    );
    expect(calls, isEmpty);
    expect(
      (await db.coreConfigDao.searchRow(rawId))!.data,
      renamed.original!.data,
    );
    await expectLater(
      service.save(changed, confirmReconnect: () async => true),
      throwsA(isA<ConnectionHostException>()),
    );
    expect(
      (await db.coreConfigDao.searchRow(rawId))!.data,
      renamed.original!.data,
    );
    expect((await db.connectionConfigDao.read()).toJson(), before.toJson());
    expect(coordinator.state.value.phase, ConnectionPhase.failed);
    expect(coordinator.state.value.runtime, isNull);
  });

  for (final scenario in ['offline', 'unused', 'disconnect', 'reconnect']) {
    test(
      'Raw deletion preserves confirmation and runtime behavior: $scenario',
      () async {
        final rawId = await db.coreConfigDao.insertAssetRow(
          XrayRawDb.configCompanion('original', _text),
        );
        if (scenario == 'reconnect') {
          await db.coreConfigDao.insertAssetRow(
            outboundCompanion({'tag': 'server', 'protocol': 'freedom'}),
          );
        }
        final selected = scenario != 'unused';
        final configuration = ConnectionConfiguration(
          connection: ConnectionSettings(
            expert: selected,
            rawId: selected ? rawId : null,
          ),
        );
        await db.connectionConfigDao.commit(
          configurationJson: configuration.encode(),
        );
        var host = scenario == 'offline'
            ? const HostConnection(VpnStatus.disconnected)
            : HostConnection(
                VpnStatus.connected,
                runtime: _runtime('a', configuration, _text),
              );
        final calls = <String>[];
        final coordinator = await _initialize(
          ConnectionCoordinator(
            database: db,
            readRuntime: () async => null,
            needsStatusPolling: () => false,
            inspect: (_) async => host,
            prepare: (next, _) async => _runtime('b', next, _text),
            start: (runtime) async {
              calls.add('start');
              return host = HostConnection(
                VpnStatus.connected,
                runtime: runtime,
              );
            },
            stop: () async {
              calls.add('stop');
              return host = const HostConnection(VpnStatus.disconnected);
            },
          ),
        );
        final service = RawEditorService(
          database: db,
          coordinator: coordinator,
        );
        final original = (await service.load(rawId)).original!;
        expect(
          await service.delete(original, confirm: (_, _, _) async => false),
          false,
        );
        expect(await db.coreConfigDao.searchRow(rawId), original);
        expect(calls, isEmpty);

        expect(
          await service.delete(
            original,
            confirm: (active, reconnect, disconnect) async {
              expect(active, selected);
              expect(reconnect, scenario == 'reconnect');
              expect(disconnect, scenario == 'disconnect');
              return true;
            },
          ),
          true,
        );

        expect(await db.coreConfigDao.searchRow(rawId), isNull);
        expect((await coordinator.configuration).connection.expert, false);
        expect((await coordinator.configuration).connection.rawId, isNull);
        expect(calls, switch (scenario) {
          'reconnect' => ['stop', 'start'],
          'disconnect' => ['stop'],
          _ => <String>[],
        });
        expect(host.connected, scenario == 'unused' || scenario == 'reconnect');
      },
    );
  }

  test(
    'Raw deletion protects the actual runtime after commit and stop fail',
    () async {
      final a = await db.coreConfigDao.insertAssetRow(
        XrayRawDb.configCompanion('A', _text),
      );
      final b = await db.coreConfigDao.insertAssetRow(
        XrayRawDb.configCompanion('B', _text),
      );
      final saved = ConnectionConfiguration(
        connection: ConnectionSettings(expert: true, rawId: a),
      );
      final next = ConnectionConfiguration(
        connection: ConnectionSettings(expert: true, rawId: b),
      );
      await db.connectionConfigDao.commit(configurationJson: saved.encode());
      var host = HostConnection(
        VpnStatus.connected,
        runtime: _runtime('a', saved, _text),
      );
      var stops = 0;
      final coordinator = await _initialize(
        ConnectionCoordinator(
          database: db,
          readRuntime: () async => null,
          needsStatusPolling: () => false,
          inspect: (_) async => host,
          prepare: (configuration, _) async =>
              _runtime('b', configuration, _text),
          start: (runtime) async =>
              host = HostConnection(VpnStatus.connected, runtime: runtime),
          stop: () async {
            if (++stops > 1) throw const ConnectionHostException('stopFailed');
            return host = const HostConnection(VpnStatus.disconnected);
          },
        ),
      );
      await db.customStatement('''
      CREATE TRIGGER fail_save BEFORE UPDATE ON connection_config
      BEGIN SELECT RAISE(FAIL, 'fixture commit failure'); END
    ''');
      await expectLater(coordinator.apply(next), throwsA(anything));
      await db.customStatement('DROP TRIGGER fail_save');
      expect(coordinator.state.value.phase, ConnectionPhase.failed);
      expect((await coordinator.configuration).connection.rawId, a);
      expect(
        coordinator.state.value.runtime!.configuration.connection.rawId,
        b,
      );
      final service = RawEditorService(database: db, coordinator: coordinator);
      final original = (await service.load(b)).original!;

      await expectLater(
        service.delete(
          original,
          confirm: (_, _, _) async =>
              fail('Unsafe deletion must not be offered'),
        ),
        throwsA(
          isA<RawEditorException>().having(
            (e) => e.reason,
            'reason',
            'changed',
          ),
        ),
      );

      expect(await db.coreConfigDao.searchRow(b), original);
      expect((await coordinator.configuration).encode(), saved.encode());
      expect(host.runtime!.configuration.connection.rawId, b);
      expect(stops, 2);
    },
  );

  test('failed Raw database save rolls staged Geodata back', () async {
    final coordinator = await _initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
      ),
    );
    final service = RawEditorService(
      database: db,
      coordinator: coordinator,
      validate: (_) async => true,
    );
    await db.customStatement('''
      CREATE TRIGGER fail_raw_save BEFORE INSERT ON core_config
      WHEN NEW.type = 'raw' BEGIN SELECT RAISE(FAIL, 'fixture'); END
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
        const RawEditorDraft(name: 'original', text: _text),
        confirmReconnect: () async => false,
        geodata: geodata,
      ),
      throwsA(anything),
    );

    expect(lifecycle, ['publish', 'commit', 'rollback']);
    expect(await db.coreConfigDao.allRawRowsWithData, isEmpty);
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
  String text,
) {
  final id = List.filled(32, digit).join();
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
