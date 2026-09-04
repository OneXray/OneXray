import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/launch/setup.dart';
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
        await db.connectionStateDao.commit(settingsJson: value.encode());
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

  test('confirmed region persists before progress; skip preserves configuration and Raw activation', () async {
    await setup.acceptPrivacy();
    await setup.continueSystem('');
    final expert = ConnectionConfiguration(
      connection: ConnectionSettings(expert: true, rawId: 7),
    );
    await db.connectionStateDao.commit(settingsJson: expert.encode());
    await setup.continueRegion('RU');
    final saved = await setup.configuration();
    expect(saved.connection.smart.directRegions, ['RU']);
    expect(saved.connection.expert, isTrue);
    expect(saved.connection.rawId, 7);
    expect(await setup.currentStep(), SetupStep.servers);
    final previousWrites = writes;
    await setup.continueRegion(null);
    expect(writes, previousWrites);
    expect((await setup.configuration()).encode(), saved.encode());
    expect(await preferences.readFirstRun(), isTrue);
    await setup.finish();
    expect(await setup.currentStep(), SetupStep.complete);
    expect((await setup.configuration()).encode(), saved.encode());
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
      expect(await setup.hasServers(), isFalse);
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
      expect(await setup.hasServers(), isTrue);
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
}
