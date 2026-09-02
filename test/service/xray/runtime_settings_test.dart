import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/plan.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/xray/runtime_files.dart';
import 'package:onexray/service/xray/runtime_settings.dart';

void main() {
  late AppDatabase db;
  late ConnectionCoordinator coordinator;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    coordinator = ConnectionCoordinator(
      database: db,
      inspect: (_) async => const HostConnection(VpnStatus.disconnected),
      start: (_) async => throw StateError('Unexpected VPN start'),
      stop: (_) async => throw StateError('Unexpected VPN stop'),
    );
    addTearDown(coordinator.dispose);
    await coordinator.initialize(poll: false, registerReferences: false);
  });

  test(
    'log save preserves Raw text and concurrently changed platform preferences',
    () async {
      const text = '{ "log": {"loglevel":"debug"}, "outbounds": [] }';
      final data = base64Encode(utf8.encode(text));
      final id = await db.coreConfigDao.insertRow(
        CoreConfigCompanion.insert(
          name: 'Raw',
          type: 'raw',
          tags: '',
          delay: 0,
          subId: 0,
          data: Value(data),
        ),
      );
      final base = ConnectionConfiguration(
        connection: ConnectionSettings(expert: true, rawId: id),
      );
      await coordinator.apply(base, affectsRuntime: false);
      await coordinator.apply(
        ConnectionConfiguration(
          connection: base.connection,
          policy: PlatformPolicy.fromJson({
            ...base.policy.toJson(),
            'ipv6Enabled': false,
          }),
        ),
        affectsRuntime: false,
      );
      expect(
        await saveRuntimeLogPolicy(
          coordinator: coordinator,
          base: base,
          log: {
            ...base.policy.toJson()['log'] as Map<String, dynamic>,
            'enabled': true,
          },
          confirmReconnect: () async =>
              throw StateError('Disconnected edits must not ask to reconnect'),
        ),
        isTrue,
      );
      final saved = await coordinator.configuration;
      expect(saved.policy.ipv6Enabled, isFalse);
      expect(saved.policy.logEnabled, isTrue);
      expect(saved.policy.recordDns, isTrue);
      expect(saved.policy.maskAddress, 'full');
      expect((await db.coreConfigDao.searchRow(id))!.data, data);
    },
  );

  test(
    'cancelled reconnect and stale log draft never overwrite current settings',
    () async {
      final base = await coordinator.configuration;
      final next = {
        ...base.policy.toJson()['log'] as Map<String, dynamic>,
        'enabled': true,
      };
      coordinator.state.value = const ConnectionView(
        phase: ConnectionPhase.connected,
      );
      expect(
        await saveRuntimeLogPolicy(
          coordinator: coordinator,
          base: base,
          log: next,
          confirmReconnect: () async => false,
        ),
        isFalse,
      );
      expect((await coordinator.configuration).encode(), base.encode());
      coordinator.state.value = const ConnectionView();
      await coordinator.apply(
        ConnectionConfiguration(
          policy: PlatformPolicy.fromJson({
            ...base.policy.toJson(),
            'log': {...next, 'level': 'error'},
          }),
        ),
        affectsRuntime: false,
      );
      await expectLater(
        saveRuntimeLogPolicy(
          coordinator: coordinator,
          base: base,
          log: next,
          confirmReconnect: () async => true,
        ),
        throwsA(isA<ConnectionHostException>()),
      );
      expect((await coordinator.configuration).policy.logLevel, 'error');
    },
  );

  test('runtime configuration viewer preserves confirmed text without looking up a path', () async {
    const text = '{"secret":"kept only in the local view"}\n';
    expect(
      await RuntimeDiagnosticFiles.readConfiguration(
        text: text,
        path: '/not/a/real/file',
      ),
      text,
    );
    await expectLater(
      RuntimeDiagnosticFiles.readConfiguration(),
      throwsA(anything),
    );
  });
}
