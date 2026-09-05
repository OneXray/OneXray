import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/service/connection/compiler.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/platform_policy.dart';
import 'package:onexray/service/connection/policy_editor.dart';
import 'package:onexray/service/connection/runtime_host.dart';
import 'package:onexray/service/connection/settings.dart';

void main() {
  late AppDatabase db;
  late ConnectionCoordinator coordinator;
  late HostConnection host;
  late int stops;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    host = const HostConnection(VpnStatus.disconnected);
    stops = 0;
    coordinator = ConnectionCoordinator(
      database: db,
      inspect: (_) async => host,
      prepare: (_, _) async => throw StateError('Must not prepare'),
      start: (_) async => throw StateError('Must not start'),
      stop: () async {
        stops++;
        return host = const HostConnection(VpnStatus.disconnected);
      },
    );
    await coordinator.initialize(poll: false, registerReferences: false);
    addTearDown(() async {
      coordinator.dispose();
      await db.close();
    });
  });

  test(
    'restoring defaults changes only the draft, not storage or VPN',
    () async {
      final service = PolicyEditorService(
        coordinator: coordinator,
        platform: ConnectionPlatform.android,
      );
      final seed = await service.load();
      seed.policy['ipv6Enabled'] = false;
      seed.policy['android']['appScope'] = 'excluded';
      seed.policy['android']['excludedAppPackageNames'] = [
        'com.example.bypass',
      ];
      seed.policy['log']['enabled'] = true;
      await service.save(
        draft: seed,
        confirm: (_) async => throw StateError('Must not confirm'),
      );
      final original = await service.load();
      final stored = (await db.connectionConfigDao.read()).configurationJson;
      final controller = PolicyEditorController(
        draft: original,
        service: service,
      );
      addTearDown(controller.close);

      controller.restoreDefaults();

      expect(controller.value, PlatformPolicy.defaults().toJson());
      expect(controller.draft!.original, same(original.original));
      expect(original.policy, original.original.policy.toJson());
      expect(controller.error, isNull);
      expect((await db.connectionConfigDao.read()).configurationJson, stored);
      expect(stops, 0);
      expect(host.status, VpnStatus.disconnected);
    },
  );

  test(
    'drafts are isolated and both Android lists survive empty included saves',
    () async {
      final service = PolicyEditorService(
        coordinator: coordinator,
        platform: ConnectionPlatform.android,
      );
      final original = await service.load();
      final changed = original.copy();
      changed.policy['android']['appScope'] = 'included';
      changed.policy['android']['excludedAppPackageNames'] = [
        'com.example.excluded',
      ];
      expect(original.policy['android']['appScope'], 'all');
      expect(
        await service.save(
          draft: changed,
          confirm: (_) async => throw StateError('No confirmation'),
        ),
        true,
      );
      final stored = await coordinator.configuration;
      expect(stored.connection.toJson(), original.original.connection.toJson());
      expect(stored.policy.toJson()['android'], {
        'appScope': 'included',
        'includedAppPackageNames': [],
        'excludedAppPackageNames': ['com.example.excluded'],
      });
      expect(
        () => stored.policy.toTun(ConnectionPlatform.android),
        throwsFormatException,
      );
      await expectLater(
        service.save(draft: original, confirm: (_) async => true),
        throwsA(isA<ConnectionHostException>()),
      );
      expect(stops, 0);
    },
  );

  test(
    'empty included scope needs explicit disconnect approval and never starts',
    () async {
      final service = PolicyEditorService(
        coordinator: coordinator,
        platform: ConnectionPlatform.android,
      );
      final draft = await service.load();
      draft.policy['android']['appScope'] = 'included';
      host = HostConnection(
        VpnStatus.connected,
        runtime: _runtime(draft.original),
      );
      expect(
        await service.save(
          draft: draft,
          confirm: (disconnect) async {
            expect(disconnect, true);
            return false;
          },
        ),
        false,
      );
      expect(stops, 0);
      expect(
        (await coordinator.configuration).encode(),
        draft.original.encode(),
      );
      expect(
        await service.save(
          draft: draft,
          confirm: (disconnect) async {
            expect(disconnect, true);
            return true;
          },
        ),
        true,
      );
      expect(stops, 1);
      expect(host.status, VpnStatus.disconnected);
      expect(
        PolicyEditorService.emptyAndroidScope(
          (await coordinator.configuration).policy,
        ),
        true,
      );
    },
  );

  test(
    'runtime comparison ignores inactive lists and the other Apple network',
    () {
      final a = PlatformPolicy.defaults();
      final json = a.toJson();
      json['android']['includedAppPackageNames'] = ['com.example.included'];
      json['android']['excludedAppPackageNames'] = ['com.example.excluded'];
      final b = PlatformPolicy.fromJson(json);
      expect(
        PolicyEditorService.sameRuntime(a, b, ConnectionPlatform.android),
        true,
      );
      json['android']['appScope'] = 'included';
      expect(
        PolicyEditorService.sameRuntime(
          a,
          PlatformPolicy.fromJson(json),
          ConnectionPlatform.android,
        ),
        false,
      );

      final apple = a.toJson();
      apple['apple']['onDemandEnabled'] = true;
      final ios = PlatformPolicy.fromJson(apple);
      apple['apple']['ethernetAction'] = 'disconnect';
      final macChange = PlatformPolicy.fromJson(apple);
      expect(
        PolicyEditorService.sameRuntime(ios, macChange, ConnectionPlatform.ios),
        true,
      );
      expect(
        PolicyEditorService.sameRuntime(
          ios,
          macChange,
          ConnectionPlatform.macos,
        ),
        false,
      );
    },
  );

  test(
    'Windows uses full existing CIDR policy and never removes IPv6 conflicts',
    () {
      final service = PolicyEditorService(
        coordinator: coordinator,
        platform: ConnectionPlatform.windows,
      );
      final original = ConnectionConfiguration(
        policy: PlatformPolicy.fromJson({
          'xrayOutboundInterfaceName': 'Ethernet',
        }),
      );
      final draft = PolicyEditorDraft(original);
      draft.policy['windows']['excludedCidrs'] = [' 192.168.1.0/24 ', ''];
      expect(
        service.validate(draft).toWindowsPolicy().toJson()['excludedCidrs'],
        ['192.168.1.0/24'],
      );
      draft.policy['windows']['excludedCidrs'] = ['fd00::/64'];
      draft.policy['ipv6Enabled'] = false;
      expect(() => service.validate(draft), throwsFormatException);
      expect(draft.policy['windows']['excludedCidrs'], ['fd00::/64']);
      draft.policy['windows']['excludedCidrs'] = ['192.168.1.1/24'];
      expect(() => service.validate(draft), throwsFormatException);
    },
  );
}

ConnectionRuntime _runtime(ConnectionConfiguration configuration) {
  const id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const text = '{"outbounds":[{"protocol":"freedom"}]}';
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
      jsonEncode(
        LibXrayInvokeRequest(
          method: LibXrayMethod.runXray,
          payload: RunXrayRequest(
            text,
            runtime: ManagedRuntimeRequest(
              statePath: '/fixture/run/runtime.json',
              token: id,
            ),
          ).toJson(),
        ).toJson(),
      ),
    ),
  );
}
