import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:onexray/service/servers/subscription/model.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/ping/batch.dart';
import 'package:onexray/service/shared/ping/service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AppDatabase db;
  late PreferencesKey preferences;
  late SetupService setup;
  var failLocal = false;
  var granted = true;
  var writes = 0;
  var requests = 0;

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() async {
    await SharedPreferencesAsync().clear();
    preferences = PreferencesKey();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    failLocal = false;
    granted = true;
    writes = 0;
    requests = 0;
    setup = SetupService(
      database: db,
      platform: ConnectionPlatform.ios,
      prepareLocal: () async {
        if (failLocal) throw const SetupFailure('local');
      },
      permission: (request) async {
        if (request) requests++;
        return PlatformPermissionResult(
          kind: PlatformPermissionKind.appleVpn,
          state: granted
              ? PlatformPermissionState.granted
              : PlatformPermissionState.denied,
        );
      },
      readRegionCodes: () async => ['CN', 'RU', 'US'],
      saveConfiguration: (value) async {
        writes++;
        await db.connectionConfigDao.commit(configurationJson: value.encode());
      },
    );
  });

  test(
    'privacy and required setup must finish before optional steps',
    () async {
      expect(await setup.currentStep(), SetupStep.welcome);
      await setup.acceptPrivacy();
      expect(await setup.currentStep(), SetupStep.system);
      failLocal = true;
      await expectLater(setup.continueSystem(''), throwsA(isA<SetupFailure>()));
      expect(await setup.currentStep(), SetupStep.system);
      expect(await preferences.readFirstRun(), isTrue);
      failLocal = false;
      granted = false;
      await expectLater(setup.continueSystem(''), throwsA(isA<SetupFailure>()));
      expect(writes, 0);
      granted = true;
      await setup.continueSystem('');
      expect(await setup.currentStep(), SetupStep.region);
      expect(
        requests,
        0,
      ); // Existing permission is reused; setup never starts VPN.
      expect(
        (await setup.configuration()).connection.selection.kind,
        SelectionKind.automatic,
      );
      expect((await setup.configuration()).policy.ipv6Enabled, isTrue);
    },
  );

  test(
    'subscription import allows Home before any speed test completes',
    () async {
      final bus = AppEventBus();
      addTearDown(bus.close);
      final started = Completer<void>();
      final release = Completer<void>();
      Future<void>? drained;
      addTearDown(() async {
        if (!release.isCompleted) release.complete();
        await drained;
      });
      final ping = PingService.forTesting(
        database: db,
        automaticEnabled: false,
        runBatch: (sources, _) async {
          if (!started.isCompleted) started.complete();
          await release.future;
          return [for (final _ in sources) const PingBatchResult(true, 20, '')];
        },
      );
      final subscriptions = SubscriptionService.forTesting(
        database: db,
        loadRows: (_) async => SubscriptionLoadResult(
          status: SubscriptionUpdateResult.success,
          rows: [
            CoreConfigCompanion.insert(
              name: 'Setup node',
              type: 'outbound',
              subId: 0,
              tags: 'socks',
              delay: PingDelayConstants.unknown,
              data: Value(
                base64Encode(
                  utf8.encode(
                    jsonEncode({
                      'outbounds': [
                        {'tag': 'Setup node', 'protocol': 'freedom'},
                      ],
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
        schedulePing: ping.schedulePingSubscription,
      );
      await setup.acceptPrivacy();
      await setup.continueSystem('');
      await setup.continueRegion(null);
      final ready = setup.watchHasServers().firstWhere(
        (hasServers) => hasServers,
      );
      final imported = await subscriptions.insertSubscription(
        const SubscriptionInput(
          name: 'Setup',
          url: 'https://example.com/setup',
        ),
      );
      expect(imported.success, isTrue);
      await ready;
      await setup.finish().timeout(const Duration(seconds: 1));
      expect(await setup.currentStep(), SetupStep.complete);
      expect(started.isCompleted, isFalse);
      expect(ping.isPinging, isFalse);
      expect(await db.coreConfigDao.unmeasuredOutboundIds, hasLength(1));

      drained = bus.stream
          .skipWhile((state) => !state.pinging)
          .firstWhere((state) => !state.pinging)
          .then((_) {});
      ping.startAutomatic();
      await started.future.timeout(const Duration(seconds: 5));
      expect(release.isCompleted, isFalse);
      expect(await setup.currentStep(), SetupStep.complete);
      release.complete();
      await drained;
      expect(await db.coreConfigDao.unmeasuredOutboundIds, isEmpty);
    },
  );

  test('every platform uses the native permission result', () async {
    for (final platform in ConnectionPlatform.values) {
      for (final nativeState in [
        PlatformPermissionState.denied,
        PlatformPermissionState.notRequired,
      ]) {
        final calls = <bool>[];
        final service = SetupService(
          platform: platform,
          permission: (request) async {
            calls.add(request);
            return PlatformPermissionResult(
              kind: PlatformPermissionKind.appleVpn,
              state: nativeState,
            );
          },
        );
        for (final request in [false, true]) {
          final result = await service.checkPermission(request: request);
          expect(result.state, nativeState);
        }
        expect(calls, [false, true]);
      }
    }
  });

  test('setup accepts a native simulator permission exemption', () async {
    var queries = 0;
    final service = SetupService(
      database: db,
      platform: ConnectionPlatform.ios,
      prepareLocal: () async {},
      permission: (request) async {
        expect(request, isFalse);
        queries++;
        return PlatformPermissionResult(
          kind: PlatformPermissionKind.appleVpn,
          state: PlatformPermissionState.notRequired,
        );
      },
      readRegionCodes: () async => ['CN', 'RU'],
    );
    await service.acceptPrivacy();
    await service.continueSystem('');
    expect(await service.currentStep(), SetupStep.region);
    await service.continueRegion(null);
    expect(await service.currentStep(), SetupStep.servers);
    await service.finish();
    expect(await service.currentStep(), SetupStep.complete);
    expect(queries, 2);
  });

  test('confirmed regions persist before progress; skip preserves configuration and Raw activation', () async {
    await setup.acceptPrivacy();
    await setup.continueSystem('');
    final expert = ConnectionConfiguration(
      connection: ConnectionSettings(expert: true, rawId: 7),
    );
    await db.connectionConfigDao.commit(configurationJson: expert.encode());
    await expectLater(
      setup.continueRegion(['RU', 'UNKNOWN']),
      throwsA(isA<SetupFailure>()),
    );
    expect(await setup.currentStep(), SetupStep.region);
    expect((await setup.configuration()).encode(), expert.encode());
    await setup.continueRegion(['RU', 'CN']);
    final saved = await setup.configuration();
    expect(saved.connection.smart.directRegions, ['RU', 'CN']);
    expect(saved.connection.expert, isTrue);
    expect(saved.connection.rawId, 7);
    expect(await setup.currentStep(), SetupStep.servers);
    final previousWrites = writes;
    await setup.continueRegion(null);
    expect(writes, previousWrites);
    expect((await setup.configuration()).encode(), saved.encode());
    await setup.continueRegion([]);
    final cleared = await setup.configuration();
    expect(cleared.connection.smart.directRegions, isEmpty);
    expect(cleared.connection.expert, isTrue);
    expect(cleared.connection.rawId, 7);
    expect(await preferences.readFirstRun(), isTrue);
    await setup.finish();
    expect(await setup.currentStep(), SetupStep.complete);
    expect((await setup.configuration()).encode(), cleared.encode());
  });

  test(
    'server detection ignores retired/Raw rows and never depends on probes',
    () async {
      for (final type in ['raw', 'setting', 'full']) {
        await db.coreConfigDao.insertRow(
          CoreConfigCompanion.insert(
            name: type,
            type: type,
            tags: '',
            delay: -1,
            subId: 0,
            data: Value(base64Encode(utf8.encode('{}'))),
          ),
        );
      }
      expect(await setup.watchHasServers().first, isFalse);
      await db.coreConfigDao.insertRow(
        CoreConfigCompanion.insert(
          name: 'Unmeasured server',
          type: 'outbound',
          tags: '',
          delay: -1,
          subId: 0,
          data: Value(
            base64Encode(utf8.encode('{"protocol":"freedom","tag":"node"}')),
          ),
        ),
      );
      expect(await setup.watchHasServers().first, isTrue);
    },
  );

  test(
    'default setup save writes configuration without runtime startup',
    () async {
      final direct = SetupService(
        database: db,
        platform: ConnectionPlatform.ios,
        prepareLocal: () async {},
        permission: (_) async => PlatformPermissionResult(
          kind: PlatformPermissionKind.appleVpn,
          state: PlatformPermissionState.granted,
        ),
        readRegionCodes: () async => ['CN', 'RU'],
      );

      await direct.acceptPrivacy();
      await direct.continueSystem('');
      await direct.continueRegion(['RU']);

      expect((await direct.configuration()).connection.smart.directRegions, [
        'RU',
      ]);
    },
  );

  test('revoked permission does not write completion and returns to required preparation', () async {
    await setup.acceptPrivacy();
    await setup.continueSystem('');
    await setup.continueRegion(null);
    granted = false;
    await expectLater(setup.finish(), throwsA(isA<SetupFailure>()));
    expect(await preferences.readFirstRun(), isTrue);
    expect(await setup.currentStep(), SetupStep.system);
  });

  for (final failure in <(String, Object)>[
    ('offline or DNS failure', const SocketException('Failed host lookup')),
    ('timeout', TimeoutException('Region suggestion timed out')),
    ('invalid JSON', const FormatException('Invalid region response')),
  ]) {
    test('region suggestion ${failure.$1} does not block setup', () async {
      await setup.acceptPrivacy();
      await setup.continueSystem('');

      final suggested = await HttpOverrides.runZoned(
        setup.suggestRegion,
        createHttpClient: (_) => _FailingHttpClient(failure.$2),
      );

      expect(suggested, isNull);
      expect(await setup.currentStep(), SetupStep.region);
      await setup.continueRegion(null);
      expect(await setup.currentStep(), SetupStep.servers);
    });
  }
}

class _FailingHttpClient implements HttpClient {
  final Object failure;

  _FailingHttpClient(this.failure);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl) {
      return Future<HttpClientRequest>.error(failure);
    }
    if (invocation.memberName == const Symbol('connectionTimeout=') ||
        invocation.memberName == const Symbol('findProxy=') ||
        invocation.memberName == #close) {
      return null;
    }
    return super.noSuchMethod(invocation);
  }
}
