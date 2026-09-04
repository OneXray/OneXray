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
    await db.connectionStateDao.commit(settingsJson: configuration.encode());
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
    await db.connectionStateDao.commit(settingsJson: configuration.encode());
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
    final before = await db.connectionStateDao.read();
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
    expect((await db.connectionStateDao.read()).toJson(), before.toJson());
    expect(coordinator.state.value.phase, ConnectionPhase.failed);
    expect(coordinator.state.value.runtime, isNull);
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
      settingsJson: jsonEncode(configuration.connection.toJson()),
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
