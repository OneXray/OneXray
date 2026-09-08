import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/service/advanced/xray/geodata/model.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/service/advanced/policy_editor.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/runtime_host.dart';
import 'package:onexray/service/shared/maintenance/data_maintenance.dart';
import 'package:onexray/service/shared/ping/batch.dart';
import 'package:onexray/service/shared/ping/service.dart';
import 'package:onexray/service/servers/subscription/model.dart';
import 'package:onexray/service/servers/subscription/service.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late Directory workspace;
  late Directory datRoot;
  late AppDatabase db;
  late GeoDataService service;
  var dbClosed = false;
  var revision = 'one';
  String? failDownload;
  String? failIndex;
  var downloads = 0;
  Future<void> Function()? beforeDownload;

  Future<void> count(String path, String name, GeoDataType type) async {
    if (failIndex == name) throw const FormatException('Invalid fixture data');
    final data = await File(p.join(path, '$name.dat')).readAsString();
    if (data == 'broken') throw const FormatException('Invalid fixture data');
    await File(p.join(path, '$name.json')).writeAsString(
      jsonEncode({
        'categoryCount': 1,
        'ruleCount': 2,
        'codes': [
          {'code': type == GeoDataType.ip ? 'cn' : 'CN', 'ruleCount': 2},
        ],
      }),
    );
  }

  Future<void> expectFlatRoot() async {
    final entries = await datRoot.list(followLinks: false).toList();
    expect(
      await Future.wait(
        entries.map(
          (entry) => FileSystemEntity.type(entry.path, followLinks: false),
        ),
      ),
      everyElement(FileSystemEntityType.file),
    );
  }

  Future<Map<String, List<int>>> rootBytes() async {
    final result = <String, List<int>>{};
    await for (final entry in datRoot.list(followLinks: false)) {
      if (entry is File) {
        result[p.basename(entry.path)] = await entry.readAsBytes();
      }
    }
    return result;
  }

  setUp(() async {
    final bus = AppEventBus();
    addTearDown(bus.close);
    final fixtures = await Directory('../references/onexray-tests').absolute
        .create(recursive: true);
    workspace = await fixtures.createTemp('geodata-');
    datRoot = Directory(p.join(workspace.path, 'dat'));
    addTearDown(() => workspace.delete(recursive: true));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dbClosed = false;
    addTearDown(() async {
      if (!dbClosed) await db.close();
    });
    revision = 'one';
    failDownload = null;
    failIndex = null;
    downloads = 0;
    beforeDownload = null;
    service = GeoDataService.forTesting(
      database: db,
      directory: datRoot.path,
      download: (url, file) async {
        expect(AppEventBus.instance.state.downloading, isTrue);
        downloads++;
        await beforeDownload?.call();
        if (p.basenameWithoutExtension(file.path) == failDownload) {
          throw const SocketException('Fixture download failed');
        }
        await file.writeAsString(revision);
      },
      count: count,
      copyBundled: (path) async {
        for (final name in ['geoip', 'geosite']) {
          await File(p.join(path, '$name.dat')).writeAsString('bundled');
        }
        await File(p.join(path, 'timestamp.txt')).writeAsString('123');
      },
    );
  });

  GeoDataInput input([String name = 'custom.dat']) => GeoDataInput(
    fileName: name,
    type: GeoDataType.domain,
    url: 'https://example.com/$name',
  );

  test(
    'Geodata download does not block tunnel save or installed reads',
    () async {
      await service.ensureInstalled();
      final coordinator = ConnectionCoordinator(
        database: db,
        inspect: (_) async => const HostConnection(VpnStatus.disconnected),
        prepare: (_, _) async => throw StateError('Must not prepare'),
        start: (_) async => throw StateError('Must not start'),
        stop: () async => throw StateError('Must not stop'),
      );
      addTearDown(coordinator.dispose);
      await coordinator.initialize(poll: false, registerReferences: false);
      final editor = PolicyEditorService(
        coordinator: coordinator,
        platform: ConnectionPlatform.ios,
      );
      final draft = await editor.load();
      draft.policy['ipv6Enabled'] = false;
      final started = Completer<void>();
      final release = Completer<void>();
      beforeDownload = () async {
        if (!started.isCompleted) started.complete();
        await release.future;
      };
      final update = service.updateDefaults();
      await started.future;
      final saving = editor.save(
        draft: draft,
        confirm: (_) async => fail('Must not reconnect'),
      );
      try {
        expect(await saving.timeout(const Duration(seconds: 1)), isTrue);
        expect(
          await service.publishedFiles().timeout(const Duration(seconds: 1)),
          hasLength(2),
        );
        expect((await coordinator.configuration).policy.ipv6Enabled, isFalse);
        expect(release.isCompleted, isFalse);
      } finally {
        release.complete();
        await update;
        await saving;
      }
    },
  );

  test('publication waits for file readers but unrelated tasks keep running', () async {
    await service.ensureInstalled();
    final downloading = Completer<void>();
    final releaseDownload = Completer<void>();
    final reading = Completer<void>();
    final releaseReader = Completer<void>();
    beforeDownload = () async {
      if (!downloading.isCompleted) downloading.complete();
      await releaseDownload.future;
    };
    var published = false;
    final update = service.updateDefaults().then((_) => published = true);
    await downloading.future;
    final reader = service.withFiles(() async {
      // A nested read shares the same access, instead of queuing behind itself.
      expect(await service.publishedFiles(), hasLength(2));
      reading.complete();
      await releaseReader.future;
      expect(
        await File(p.join(datRoot.path, 'geoip.dat')).readAsString(),
        'bundled',
      );
    });
    try {
      await reading.future;
      releaseDownload.complete();
      expect(await DataMaintenance.run(() async => 1), 1);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(published, isFalse);
    } finally {
      if (!releaseDownload.isCompleted) releaseDownload.complete();
      releaseReader.complete();
      await reader;
      await update;
    }
    expect(
      await File(p.join(datRoot.path, 'geoip.dat')).readAsString(),
      revision,
    );
  });

  GeoDataService createService(AppDatabase database) =>
      GeoDataService.forTesting(
        database: database,
        directory: datRoot.path,
        download: (url, file) async {
          downloads++;
          await file.writeAsString(revision);
        },
        count: count,
        copyBundled: (path) async {
          for (final name in ['geoip', 'geosite']) {
            await File(p.join(path, '$name.dat')).writeAsString('bundled');
          }
          await File(p.join(path, 'timestamp.txt')).writeAsString('123');
        },
      );

  test(
    'local install creates both bundled defaults in the flat root',
    () async {
      await service.ensureInstalled();

      final files = await service.publishedFiles();
      expect(downloads, 0);
      expect(files.map((file) => file.row.id).toSet(), {-1, -2});
      expect(files.map((file) => file.data.parent.path).toSet(), {
        datRoot.path,
      });
      expect(files.map((file) => file.indexFile.parent.path).toSet(), {
        datRoot.path,
      });
      expect(await db.geoDataDao.allRows, isEmpty);
      expect(
        files.every(
          (file) => file.row.timestamp.millisecondsSinceEpoch == 123000,
        ),
        isTrue,
      );
      expect(
        await File(p.join(datRoot.path, 'geoip.dat')).readAsString(),
        'bundled',
      );
      expect(
        await File(p.join(datRoot.path, 'geosite.dat')).readAsString(),
        'bundled',
      );
      await expectFlatRoot();

      await service.ensureInstalled();
      expect(
        await db.geoDataDao.publishedRows,
        files.map((file) => file.row).toList(),
      );
    },
  );

  test('home readiness does not wait for setup import probes', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await service.ensureInstalled();
    final started = Completer<void>();
    final release = Completer<void>();
    final ping = PingService.forTesting(
      database: db,
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
                      {
                        'tag': 'Setup node',
                        'protocol': 'socks',
                        'settings': {'address': '127.0.0.1', 'port': 1080},
                      },
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
    Future<void>? homeReady;
    final drained = AppEventBus.instance.stream
        .skipWhile((state) => !state.pinging)
        .firstWhere((state) => !state.pinging);
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      await drained;
      await homeReady;
    });
    for (final name in ['First', 'Second']) {
      final result = await subscriptions.insertSubscription(
        SubscriptionInput(name: name, url: 'https://example.com/$name'),
      );
      expect(result.success, isTrue);
    }
    await started.future;
    expect(
      await DataMaintenance.run(service.publishedFiles)
          .timeout(const Duration(seconds: 1)),
      hasLength(2),
    );

    // ServiceManager awaits this check before building the home page.
    homeReady = service.ensureInstalled();
    await homeReady.timeout(const Duration(seconds: 1));
    expect(ping.isPinging, isTrue);
    expect(release.isCompleted, isFalse);
    release.complete();
    await drained;
    expect(ping.isPinging, isFalse);
    expect((await db.select(db.coreConfig).get()).map((row) => row.delay), [
      20,
      20,
    ]);
  });

  test('failed initial installation can be retried', () async {
    failIndex = 'geosite';
    await expectLater(service.ensureInstalled(), throwsFormatException);
    failIndex = null;

    await service.ensureInstalled();

    expect(await service.publishedFiles(), hasLength(2));
  });

  test('deleted dat directory rebuilds a clean default publication', () async {
    await service.ensureInstalled();
    await service.add(input());
    await datRoot.delete(recursive: true);

    await service.ensureInstalled();

    expect((await db.geoDataDao.publishedRows).map((row) => row.id).toSet(), {
      -2,
      -1,
    });
    expect((await service.publishedFiles()).length, 2);
    expect(await File(p.join(datRoot.path, 'geoip.dat')).exists(), isTrue);
    expect(await File(p.join(datRoot.path, 'geosite.dat')).exists(), isTrue);
    expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isFalse);
    expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isFalse);
  });

  test('deleted database file discards orphaned dat files', () async {
    await db.close();
    dbClosed = true;
    final databaseFile = File(p.join(workspace.path, 'db.sqlite'));
    var database = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final installed = createService(database);
    await installed.ensureInstalled();
    await installed.add(input());
    await database.connectionConfigDao.commit(
      configurationJson: '{"connection":{"expert":true}}',
    );
    await database.close();
    await databaseFile.delete();

    database = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(database.close);
    final recreated = createService(database);
    await recreated.ensureInstalled(resetOrphanedFiles: true);

    expect(
      (await database.geoDataDao.publishedRows).map((row) => row.id).toSet(),
      {-2, -1},
    );
    expect((await recreated.publishedFiles()).length, 2);
    expect((await database.connectionConfigDao.read()).configurationJson, '{}');
    expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isFalse);
    expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isFalse);
  });

  test('in-process data clear republishes bundled defaults', () async {
    await service.ensureInstalled();
    await service.add(input());

    await DataMaintenance.exclusive(() async {
      await db.geoDataDao.clear();
      await service.resetAfterDataClear();
    });

    expect((await db.geoDataDao.publishedRows).map((row) => row.id).toSet(), {
      -2,
      -1,
    });
    expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isFalse);
    expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isFalse);
    await expectFlatRoot();
  });

  test('nested entries are rejected instead of being merged', () async {
    await Directory(p.join(datRoot.path, 'nested')).create(recursive: true);

    await expectLater(service.ensureInstalled(), throwsStateError);
    expect(downloads, 0);
    expect(await db.geoDataDao.publishedRows, isEmpty);
  });

  test(
    'unregistered flat files are rejected instead of being merged',
    () async {
      await datRoot.create();
      await File(p.join(datRoot.path, 'legacy.dat')).writeAsString('legacy');

      await expectLater(service.ensureInstalled(), throwsStateError);

      expect(await db.geoDataDao.publishedRows, isEmpty);
      expect(
        await File(p.join(datRoot.path, 'legacy.dat')).readAsString(),
        'legacy',
      );
    },
  );

  for (final damage in [
    'orphan',
    'missing DAT',
    'missing index',
    'invalid index',
  ]) {
    test('cold startup rejects $damage with an existing manifest', () async {
      await service.ensureInstalled();
      await service.add(input());
      await service.ensureInstalled();
      final rows = await db.geoDataDao.publishedRows;
      switch (damage) {
        case 'orphan':
          await File(p.join(datRoot.path, 'orphan.dat'))
              .writeAsString('orphan');
        case 'missing DAT':
          await File(p.join(datRoot.path, 'custom.dat')).delete();
        case 'missing index':
          await File(p.join(datRoot.path, 'custom.json')).delete();
        case 'invalid index':
          await File(p.join(datRoot.path, 'custom.json')).writeAsString('{}');
      }
      final bytes = await rootBytes();
      final previousDownloads = downloads;

      await expectLater(service.ensureInstalled(), throwsA(anything));
      await expectLater(createService(db).ensureInstalled(), throwsA(anything));

      expect(await db.geoDataDao.publishedRows, rows);
      expect(await rootBytes(), bytes);
      expect(downloads, previousDownloads);
    });
  }

  test(
    'failed default updates preserve every published byte in place',
    () async {
      await service.ensureInstalled();
      final rows = await db.geoDataDao.publishedRows;
      final before = await rootBytes();

      failDownload = 'geosite';
      await expectLater(
        service.updateDefaults(),
        throwsA(isA<SocketException>()),
      );
      expect(await db.geoDataDao.publishedRows, rows);
      expect(await rootBytes(), before);

      failDownload = null;
      failIndex = 'geosite';
      await expectLater(service.updateDefaults(), throwsFormatException);
      expect(await db.geoDataDao.publishedRows, rows);
      expect(await rootBytes(), before);
      await expectFlatRoot();

      failIndex = null;
      revision = 'two';
      await service.updateDefaults();
      expect(
        await File(p.join(datRoot.path, 'geoip.dat')).readAsString(),
        'two',
      );
      expect(
        await File(p.join(datRoot.path, 'geosite.dat')).readAsString(),
        'two',
      );
      await expectFlatRoot();
    },
  );

  test(
    'custom update rolls back, overwrites in place, and delete removes files',
    () async {
      await service.ensureInstalled();
      await service.add(input());
      final original = (await service.publishedFiles()).firstWhere(
        (file) => !file.builtIn,
      );
      final dataPath = original.data.path;
      final indexPath = original.indexFile.path;
      final before = await rootBytes();

      await db.customStatement(
        "CREATE TRIGGER fail_geo_update BEFORE UPDATE ON geo_data WHEN OLD.id > 0 BEGIN SELECT RAISE(FAIL, 'fixture'); END",
      );
      revision = 'two';
      await expectLater(service.updateCustom(original.row), throwsA(anything));
      expect(await db.geoDataDao.searchRow(original.row.id), original.row);
      expect(await rootBytes(), before);
      expect(await File(dataPath).readAsString(), 'one');

      await db.customStatement('DROP TRIGGER fail_geo_update');
      await service.updateCustom(original.row);
      final updated = (await service.publishedFiles()).firstWhere(
        (file) => !file.builtIn,
      );
      expect(updated.data.path, dataPath);
      expect(updated.indexFile.path, indexPath);
      expect(await updated.data.readAsString(), 'two');
      await expectFlatRoot();

      await service.deleteGeoDat(updated.row);
      expect(await File(dataPath).exists(), isFalse);
      expect(await File(indexPath).exists(), isFalse);
      expect(await db.geoDataDao.searchRow(updated.row.id), isNull);
      await expectFlatRoot();
    },
  );

  test('failed standalone add removes its downloaded flat files', () async {
    await service.ensureInstalled();
    await db.customStatement('''
      CREATE TRIGGER fail_geo_insert BEFORE INSERT ON geo_data
      WHEN NEW.name = 'custom' BEGIN SELECT RAISE(FAIL, 'fixture'); END
    ''');

    await expectLater(service.add(input()), throwsA(anything));

    expect(await db.geoDataDao.allRows, isEmpty);
    expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isFalse);
    expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isFalse);
    await expectFlatRoot();
  });

  test(
    'import draft publishes only for commit and rolls an outer failure back',
    () async {
      await service.ensureInstalled();
      final draft = await service.prepareImports([input()]);
      final data = File(p.join(datRoot.path, 'custom.dat'));
      final index = File(p.join(datRoot.path, 'custom.json'));
      expect(await db.geoDataDao.allRows, isEmpty);
      expect(await data.exists(), isFalse);
      expect(await index.exists(), isFalse);

      await expectLater(
        draft.save((writeMetadata) async {
          expect(await data.readAsString(), 'one');
          expect(await index.exists(), isTrue);
          await expectFlatRoot();
          return db.transaction(() async {
            await writeMetadata();
            throw StateError('Config save failed');
          });
        }),
        throwsStateError,
      );
      expect(await db.geoDataDao.allRows, isEmpty);
      expect(await data.exists(), isFalse);
      expect(await index.exists(), isFalse);

      await draft.save((writeMetadata) => db.transaction(writeMetadata));
      await draft.dispose();
      expect((await db.geoDataDao.allRows).single.name, 'custom');
      expect(await data.readAsString(), 'one');
      expect(await index.exists(), isTrue);
      await expectFlatRoot();

      final before = downloads;
      await expectLater(
        service.prepareImports([input('CUSTOM.dat')]),
        throwsFormatException,
      );
      await expectLater(
        service.prepareImports([input('dup.dat'), input('Dup.dat')]),
        throwsFormatException,
      );
      await expectLater(
        service.prepareImports([input('other.DAT')]),
        throwsFormatException,
      );
      expect(downloads, before);
    },
  );

  test(
    'import completion preserves a case-insensitive committed name',
    () async {
      await service.ensureInstalled();
      final draft = await service.prepareImports([input()]);
      await draft.save(
        (_) => db.geoDataDao.insertRow(
          GeoDataCompanion.insert(
            name: 'CUSTOM',
            type: 'domain',
            url: 'https://example.com/CUSTOM.dat',
            timestamp: DateTime(2020),
            categoryCount: 1,
            ruleCount: 2,
          ),
        ),
      );

      await draft.dispose();

      expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isTrue);
      expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isTrue);
    },
  );

  test('startup removes an interrupted unpublished import', () async {
    await service.ensureInstalled();
    final draft = await service.prepareImports([input()]);
    await expectLater(
      draft.save((_) async {
        expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isTrue);
        // A new process observes the published files before the old save commits.
        await createService(db).ensureInstalled();
        throw StateError('Interrupted save');
      }),
      throwsStateError,
    );
    await draft.dispose();

    expect(await db.geoDataDao.allRows, isEmpty);
    expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isFalse);
    expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isFalse);
  });

  test('startup finishes an import committed before cleanup', () async {
    await service.ensureInstalled();
    final draft = await service.prepareImports([input()]);
    await draft.save((writeMetadata) async {
      await db.transaction(writeMetadata);
      // Simulate cold startup after SQL commit but before staging cleanup.
      await createService(db).ensureInstalled();
    });
    await draft.dispose();

    expect((await db.geoDataDao.allRows).single.name, 'custom');
    expect(
      await File(p.join(datRoot.path, 'custom.dat')).readAsString(),
      'one',
    );
    expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isTrue);
  });

  test(
    'staging an import does not block clear-data or repopulate it',
    () async {
      await service.ensureInstalled();
      final started = Completer<void>();
      final release = Completer<void>();
      beforeDownload = () async {
        if (!started.isCompleted) started.complete();
        await release.future;
      };
      final preparing = service.prepareImports([input()]);
      await started.future;
      await DataMaintenance.exclusive(
        () => service.withFiles(() async {
          await db.geoDataDao.clear();
          await service.resetAfterDataClear();
        }),
      ).timeout(const Duration(seconds: 1));
      release.complete();
      final draft = await preparing;
      expect(await db.geoDataDao.allRows, isEmpty);
      expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isFalse);
      await draft.dispose();
    },
  );

  test('cancelled import never publishes files or metadata', () async {
    await service.ensureInstalled();
    final before = await rootBytes();
    final draft = await service.prepareImports([input()]);
    await draft.dispose();
    expect(await rootBytes(), before);
    expect(await db.geoDataDao.allRows, isEmpty);
    expect(
      await workspace
          .list()
          .where(
            (entry) =>
                p.basename(entry.path).startsWith('.onexray-geodata-import-'),
          )
          .toList(),
      isEmpty,
    );
  });

  test(
    'readers wait for the whole import save, not individual phases',
    () async {
      await service.ensureInstalled();
      final draft = await service.prepareImports([input()]);
      final published = Completer<void>();
      final release = Completer<void>();
      final saving = draft.save((writeMetadata) async {
        published.complete();
        await release.future;
        await db.transaction(writeMetadata);
      });
      await published.future;
      var read = false;
      final reading = service.publishedFiles().then((files) {
        read = true;
        return files;
      });
      await Future<void>.delayed(Duration.zero);
      expect(read, isFalse);
      release.complete();
      await saving;
      expect((await reading).any((file) => file.row.name == 'custom'), isTrue);
      await draft.dispose();
    },
  );

  test('reserved IDs never overwrite existing records', () async {
    await db.geoDataDao.insertRow(
      GeoDataCompanion.insert(
        id: const Value(-1),
        name: 'user-source',
        type: 'domain',
        url: 'https://example.com/file',
        timestamp: DateTime(2020),
        categoryCount: 1,
        ruleCount: 2,
      ),
    );

    await expectLater(service.ensureInstalled(), throwsStateError);
    expect((await db.geoDataDao.publishedRows).single.name, 'user-source');
    expect(downloads, 0);
    await expectFlatRoot();
  });
}
