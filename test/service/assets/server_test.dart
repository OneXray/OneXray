import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/service/assets/server.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<CoreConfigData> server({int subId = 0, bool favorite = false}) async {
    final id = await db.coreConfigDao.insertAssetRow(
      outboundCompanion({'tag': 'original', 'protocol': 'freedom'}).copyWith(
        subId: Value(subId),
        favorite: Value(favorite),
        countryCode: const Value('JP'),
        locationSource: const Value('ip'),
        delay: const Value(20),
        lastMeasuredAt: Value(DateTime(2026, 9, 3)),
      ),
    );
    return (await db.coreConfigDao.searchRow(id))!;
  }

  Future<ConnectionCoordinator> initialize(
    ConnectionCoordinator coordinator,
  ) async {
    addTearDown(coordinator.dispose);
    await coordinator.initialize(poll: false, registerReferences: false);
    return coordinator;
  }

  test(
    'favorite and local copy preserve source identity and do not start VPN',
    () async {
      final original = await server(subId: 7, favorite: true);
      final coordinator = await initialize(
        ConnectionCoordinator(
          database: db,
          inspect: (_) async => const HostConnection(VpnStatus.disconnected),
          start: (_) async => throw StateError('Unexpected start'),
          stop: (_) async => throw StateError('Unexpected stop'),
        ),
      );
      final scheduled = <int>[];
      final service = ServerAssetService(
        database: db,
        coordinator: coordinator,
        schedule: scheduled.addAll,
        validate: (_) async => '',
      );
      final copyId = await service.copyLocal(original, 'Local copy');
      final copy = (await db.coreConfigDao.searchRow(copyId))!;
      expect(copy.subId, 0);
      expect(copy.favorite, false);
      expect(copy.countryCode, 'JP');
      expect(copy.delay, PingDelayConstants.unknown);
      expect(copy.lastMeasuredAt, isNull);
      expect(readOutboundFromDbData(copy)['tag'], 'original · Local copy');
      expect(scheduled, [copyId]);
      await service.favorite(original.id, false);
      final source = (await db.coreConfigDao.searchRow(original.id))!;
      expect(source.subId, 7);
      expect(source.data, original.data);
      expect(source.favorite, false);
    },
  );

  test('running rename is metadata-only; cancelled or failed semantic edit keeps original', () async {
    final row = await server(favorite: true);
    final configuration = ConnectionConfiguration(
      connection: ConnectionSettings(selection: ServerSelection.server(row.id)),
    );
    final old = _plan('a', configuration, [ServerSnapshot.fromRow(row)]);
    await db.connectionStateDao.commit(
      baseRevision: 0,
      settingsJson: configuration.encode(),
      confirmedSnapshotJson: old.encode(),
    );
    var host = HostConnection(VpnStatus.connected, plan: old);
    final calls = <String>[];
    final coordinator = await initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => host,
        start: (plan) async {
          calls.add('start');
          if (plan.id != old.id) {
            throw const ConnectionHostException('startFailed');
          }
          return host = HostConnection(VpnStatus.connected, plan: old);
        },
        stop: (_) async {
          calls.add('stop');
          return host = const HostConnection(VpnStatus.disconnected);
        },
      ),
    );
    final service = ServerAssetService(
      database: db,
      coordinator: coordinator,
      validate: (_) async => '',
      schedule: (_) {},
      prepare: (next, _, drafts, _) async =>
          _plan('b', next, drafts.values.toList()),
    );
    final draft = await service.load(row.id);
    expect(
      await service.save(
        ServerEditDraft(row, draft.text.replaceFirst('original', 'renamed')),
        confirmReconnect: () async =>
            throw StateError('Metadata must not confirm'),
      ),
      true,
    );
    expect(calls, isEmpty);
    final renamed = await service.load(row.id);
    expect(renamed.original.name, 'renamed');
    expect(renamed.original.favorite, true);
    expect(renamed.original.lastMeasuredAt, row.lastMeasuredAt);
    final changed = ServerEditDraft(
      renamed.original,
      renamed.text.replaceFirst('freedom', 'blackhole'),
    );
    expect(
      await service.save(changed, confirmReconnect: () async => false),
      false,
    );
    expect(calls, isEmpty);
    await expectLater(
      service.save(changed, confirmReconnect: () async => true),
      throwsA(isA<ConnectionHostException>()),
    );
    expect(
      (await db.coreConfigDao.searchRow(row.id))!.data,
      renamed.original.data,
    );
    expect(coordinator.state.value.plan!.id, old.id);
  });

  test('deleting an inactive fixed/final node clears references without starting VPN', () async {
    final row = await server(favorite: true);
    final configuration = ConnectionConfiguration(
      connection: ConnectionSettings(
        expert: true,
        rawId: 99,
        selection: ServerSelection.server(row.id),
        smart: SmartRoutingSettings(finalExitId: row.id),
      ),
    );
    await db.connectionStateDao.commit(
      baseRevision: 0,
      settingsJson: configuration.encode(),
    );
    final coordinator = await initialize(
      ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        start: (_) async => throw StateError('Unexpected start'),
        stop: (_) async => throw StateError('Unexpected stop'),
      ),
    );
    final service = ServerAssetService(
      database: db,
      coordinator: coordinator,
      validate: (_) async => '',
      schedule: (_) {},
    );
    final preview = await service.previewRemoval(ids: {row.id});
    expect(preview.affectsRuntime, false);
    await service.remove(preview);
    expect(await db.coreConfigDao.searchRow(row.id), isNull);
    final next = await coordinator.configuration;
    expect(next.connection.selection.kind, SelectionKind.automatic);
    expect(next.connection.smart.finalExitId, isNull);
    expect(next.connection.expert, true);
    expect(next.connection.rawId, 99);
  });
}

ConnectionPlan _plan(
  String digit,
  ConnectionConfiguration configuration,
  List<ServerSnapshot> entries,
) {
  final id = List.filled(32, digit).join();
  final text = jsonEncode({
    'outbounds': entries.map((row) => row.outbound).toList(),
  });
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
      entries: entries,
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
