import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/backup/codec.dart';
import 'package:onexray/core/backup/model.dart';
import 'package:onexray/core/backup/storage.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/advanced/xray/data_update/state.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime_host.dart';
import 'package:onexray/service/settings/backup/assets.dart';
import 'package:onexray/service/settings/backup/service.dart';
import 'package:onexray/service/settings/data_cleanup.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/ping/service.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late BackupAssets assets;
  late BackupService service;
  late AppDataCleanupService cleanup;
  late MemoryBackupPreferences preferences;
  late MemoryBackupStorage storage;
  var stops = 0;
  var stopFails = false;
  Future<void> Function()? beforeRestore;
  var now = DateTime(2026, 9, 16);

  Future<void> insert(String name) => db.coreConfigDao
      .insertRow(
        CoreConfigCompanion.insert(
          name: name,
          type: 'raw',
          tags: '',
          data: Value(base64Encode(utf8.encode('{ "outbounds": [] }'))),
          delay: 0,
          subId: 0,
        ),
      )
      .then((_) {});

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final bus = AppEventBus();
    addTearDown(bus.close);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final parent = await Directory('../references/onexray-tests').absolute
        .create(recursive: true);
    final root = await parent.createTemp('backup-service-');
    addTearDown(() => root.delete(recursive: true));
    final geodata = GeoDataService.forTesting(
      database: db,
      directory: '${root.path}/dat',
      download: (_, _) async => fail('Restore must stay offline'),
      count: (_, _, _) async => fail('No indexing'),
      copyBundled: (_) async => fail('No default replacement'),
    );
    assets = BackupAssets(db, geodata);
    stops = 0;
    stopFails = false;
    beforeRestore = null;
    now = DateTime(2026, 9, 16);
    final coordinator = ConnectionCoordinator(
      database: db,
      readRuntime: () async => null,
      inspect: (_) async => const HostConnection(VpnStatus.disconnected),
      prepare: (_, _) async => throw StateError('No preparation'),
      start: (_) async => throw StateError('No VPN start'),
      stop: () async {
        stops++;
        if (stopFails) throw const ConnectionHostException('stopFailed');
        return const HostConnection(VpnStatus.disconnected);
      },
    );
    await coordinator.initialize(observe: false, registerReferences: false);
    addTearDown(coordinator.dispose);
    storage = MemoryBackupStorage();
    preferences = MemoryBackupPreferences();
    service = BackupService.forTesting(
      storage: storage,
      preferences: preferences,
      assets: assets,
      now: () => now,
      restore: (commit) => cleanup.runForRestore(() async {
        await beforeRestore?.call();
        await commit();
      }),
    );
    addTearDown(service.close);
    cleanup = AppDataCleanupService.forTesting(
      coordinator: coordinator,
      geodata: geodata,
      backup: service,
      ping: PingService.forTesting(
        database: db,
        runBatch: (_, _) async => fail('No probes'),
      ),
      subscriptions: SubscriptionService.forTesting(
        database: db,
        loadRows: (_) async => fail('No subscriptions'),
        schedulePing: (_) {},
      ),
      clear: () async {
        await db.coreConfigDao.clear();
        preferences.settings = const BackupSettings();
      },
    );
  });

  Future<BackupPreview> savedPreview() async {
    await insert('Restored');
    storage.bytes = encodeBackup(await assets.capture());
    await db.coreConfigDao.clear();
    await insert('Current');
    await service.select(create: false);
    return service.preview();
  }

  test('selection and preview do not write or stop; restore works without overwrite consent', () async {
    final preview = await savedPreview();
    expect((preview.raw, preview.pending), (1, 0));
    expect((storage.writes, stops), (0, 0));
    expect(preferences.settings.confirmed, false);
    expect((await db.coreConfigDao.allRawRowsWithData).single.name, 'Current');
    expect(await service.restore(preview), 0);
    expect(stops, 1);
    expect((await db.coreConfigDao.allRawRowsWithData).single.name, 'Restored');
    expect(storage.writes, 0);
    expect(preferences.settings.confirmed, false);
  });

  test('failed stop makes no replacement and admits a later retry', () async {
    final preview = await savedPreview();
    final original = await db.coreConfigDao.allRawRowsWithData;
    stopFails = true;
    await expectLater(
      service.restore(preview),
      throwsA(isA<ConnectionHostException>()),
    );
    expect(await db.coreConfigDao.allRawRowsWithData, original);
    expect(service.state.operation, null);
    stopFails = false;
    await service.restore(preview);
    expect((await db.coreConfigDao.allRawRowsWithData).single.name, 'Restored');
  });

  test(
    'a transaction failure restores original rows and does not start VPN',
    () async {
      final preview = await savedPreview();
      final original = await db.coreConfigDao.allRawRowsWithData;
      await db.customStatement(
        "CREATE TRIGGER reject_restore BEFORE INSERT ON core_config WHEN NEW.name = 'Restored' BEGIN SELECT RAISE(ABORT, 'fixture insert failure'); END;",
      );
      await expectLater(service.restore(preview), throwsA(anything));
      expect(await db.coreConfigDao.allRawRowsWithData, original);
      expect(stops, 1);
    },
  );

  test('clear waits for accepted provider write, rejects restore, then resets binding', () async {
    final preview = await savedPreview();
    preferences.enabled = false;
    await service.confirmTarget(storage.target!.identifier);
    final accepted = Completer<void>();
    final finish = Completer<void>();
    storage.onWrite = () async {
      accepted.complete();
      await finish.future;
    };
    final writing = service.backupNow();
    await accepted.future;
    final clearing = cleanup.clearFromSettings();
    await expectLater(service.restore(preview), throwsStateError);
    expect((await db.coreConfigDao.allRawRowsWithData).single.name, 'Current');
    finish.complete();
    expect(await writing, true);
    expect(await clearing, true);
    await service.load();
    expect(service.state.settings.target, null);
    expect(storage.writes, 1);
  });

  test('restore owns destructive gate; repeated restore and clear cannot deadlock it', () async {
    final preview = await savedPreview();
    final entered = Completer<void>();
    final release = Completer<void>();
    beforeRestore = () async {
      entered.complete();
      await release.future;
    };
    final restoring = service.restore(preview);
    await entered.future;
    expect(await cleanup.clearFromSettings(), false);
    await expectLater(service.restore(preview), throwsStateError);
    release.complete();
    expect(await restoring, 0);
    expect(stops, 1);
  });

  test('auto defaults on, but load, selection and unconfirmed checks never access contents', () async {
    expect(await BackupPreferences().automatic(), true);
    await service.load();
    await service.checkAutomatic();
    await service.select(create: false);
    await service.checkAutomatic();
    expect((storage.reads, storage.writes), (0, 0));
    expect(await service.confirmTarget('fixture'), true);
    expect(storage.writes, 1);
    expect(preferences.settings.lastSuccess, now);
    await service.checkAutomatic();
    expect(storage.writes, 1);
    now = now.add(const Duration(days: 2));
    await service.checkAutomatic();
    expect(storage.writes, 1);
    preferences.period = AutoUpdateInterval.oneDay;
    await service.checkAutomatic();
    expect(storage.writes, 2);
  });

  test('disabled automatic backups do not prevent manual writes or advance a separate interval', () async {
    await service.select(create: false);
    await service.setAutomatic(false);
    expect(await service.confirmTarget('fixture'), false);
    now = now.add(const Duration(days: 10));
    await service.checkAutomatic();
    expect(storage.writes, 0);
    expect(await service.backupNow(), true);
    expect(preferences.settings.lastSuccess, now);
    await service.setAutomatic(true);
    await Future<void>.delayed(Duration.zero);
    expect(storage.writes, 1);
  });

  test('failed automatic write keeps success time and retries no sooner than one hour', () async {
    await service.select(create: false);
    await service.confirmTarget('fixture');
    final lastSuccess = now;
    now = now.add(const Duration(days: 3));
    storage.onWrite = () async =>
        throw const FileSystemException('Fixture quota exceeded');
    await service.checkAutomatic();
    expect(preferences.settings.lastSuccess, lastSuccess);
    expect(service.state.error, isA<FileSystemException>());
    expect(storage.writes, 2);
    now = now.add(const Duration(minutes: 59));
    await service.checkAutomatic();
    expect(storage.writes, 2);
    storage.onWrite = null;
    now = now.add(const Duration(minutes: 1));
    await service.checkAutomatic();
    expect(storage.writes, 3);
    expect(service.state.error, null);
    expect(preferences.settings.lastSuccess, now);
  });

  test('checks coalesce, target cannot change during write, and accepted write may finish after disabling', () async {
    await service.select(create: false);
    await service.confirmTarget('fixture', writeAutomatically: false);
    final accepted = Completer<void>();
    final release = Completer<void>();
    storage.onWrite = () async {
      accepted.complete();
      await release.future;
    };
    final writing = service.checkAutomatic();
    await accepted.future;
    await service.checkAutomatic();
    await expectLater(service.select(create: false), throwsStateError);
    await service.setAutomatic(false);
    release.complete();
    await writing;
    expect(storage.writes, 1);
    expect(service.state.automatic, false);
    expect(preferences.settings.lastSuccess, now);
    storage.target = const BackupTarget('new', 'New backup');
    await service.select(create: false);
    expect(preferences.settings.confirmed, false);
    expect(preferences.settings.lastSuccess, null);
    expect(storage.released, ['fixture']);
  });

  test(
    'disabling before provider I/O cancels an automatic write being encoded',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      service = BackupService.forTesting(
        storage: storage,
        preferences: preferences,
        assets: _HeldAssets(assets.db, assets.geodata, entered, release),
        now: () => now,
      );
      addTearDown(service.close);
      await service.select(create: false);
      await service.confirmTarget('fixture', writeAutomatically: false);
      final writing = service.checkAutomatic();
      await entered.future;
      await service.setAutomatic(false);
      release.complete();
      await writing;
      expect(storage.writes, 0);
      expect(preferences.settings.lastSuccess, null);
    },
  );

  test('a late preference read cannot undo disabling auto backup', () async {
    await service.select(create: false);
    await service.confirmTarget('fixture', writeAutomatically: false);
    final reading = Completer<void>();
    final release = Completer<void>();
    preferences.beforeInterval = () async {
      reading.complete();
      await release.future;
    };
    final checking = service.checkAutomatic();
    await reading.future;
    await service.setAutomatic(false);
    release.complete();
    await checking;
    expect(service.state.automatic, false);
    expect(storage.writes, 0);
  });

  test('cancelled selection keeps the binding and explicit unbind never deletes a file', () async {
    await service.select(create: false);
    final before = preferences.settings;
    storage.target = null;
    expect(await service.select(create: false), false);
    expect(preferences.settings, before);
    await service.unbind();
    expect(preferences.settings.target, null);
    expect(storage.released, ['fixture']);
    expect(storage.writes, 0);
  });
}

class MemoryBackupPreferences extends BackupPreferences {
  BackupSettings settings = const BackupSettings();
  bool enabled = true;
  AutoUpdateInterval period = AutoUpdateInterval.threeDays;
  Future<void> Function()? beforeInterval;
  @override
  Future<BackupSettings> read() async => settings;
  @override
  Future<void> save(BackupSettings value) async {
    settings = value;
  }

  @override
  Future<bool> automatic() async => enabled;
  @override
  Future<void> saveAutomatic(bool value) async {
    enabled = value;
  }

  @override
  Future<AutoUpdateInterval> interval() async {
    await beforeInterval?.call();
    return period;
  }
}

class MemoryBackupStorage implements BackupStorage {
  BackupTarget? target = const BackupTarget('fixture', 'Fixture backup');
  Uint8List? bytes;
  int writes = 0;
  int reads = 0;
  final released = <String>[];
  Future<void> Function()? onWrite;
  @override
  Future<BackupTarget?> select({required bool create}) async => target;
  @override
  Future<Uint8List> read(BackupTarget target) async {
    reads++;
    return bytes!;
  }

  @override
  Future<void> write(BackupTarget target, Uint8List value) async {
    writes++;
    await onWrite?.call();
    bytes = value;
  }

  @override
  Future<void> release(BackupTarget target) async {
    released.add(target.identifier);
  }
}

class _HeldAssets extends BackupAssets {
  _HeldAssets(super.db, super.geodata, this.entered, this.release);
  final Completer<void> entered;
  final Completer<void> release;
  @override
  Future<BackupDocument> capture() async {
    entered.complete();
    await release.future;
    return super.capture();
  }
}
