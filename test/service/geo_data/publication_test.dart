import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:path/path.dart' as p;

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
    service = GeoDataService.forTesting(
      database: db,
      directory: datRoot.path,
      download: (url, file) async {
        downloads++;
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

      await draft.publish();
      expect(await data.readAsString(), 'one');
      expect(await index.exists(), isTrue);
      await expectFlatRoot();

      await expectLater(
        db.transaction(() async {
          await draft.commit();
          throw StateError('Config save failed');
        }),
        throwsStateError,
      );
      await draft.rollback();
      expect(await db.geoDataDao.allRows, isEmpty);
      expect(await data.exists(), isFalse);
      expect(await index.exists(), isFalse);

      await draft.publish();
      await db.transaction(draft.commit);
      await draft.complete();
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

  test('draft cleanup preserves a case-insensitive committed name', () async {
    await service.ensureInstalled();
    final draft = await service.prepareImports([input()]);
    await draft.publish();
    await db.geoDataDao.insertRow(
      GeoDataCompanion.insert(
        name: 'CUSTOM',
        type: 'domain',
        url: 'https://example.com/CUSTOM.dat',
        timestamp: DateTime(2020),
        categoryCount: 1,
        ruleCount: 2,
      ),
    );

    await draft.dispose();

    expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isTrue);
    expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isTrue);
  });

  test('startup removes an interrupted unpublished import', () async {
    await service.ensureInstalled();
    final draft = await service.prepareImports([input()]);
    await draft.publish();
    expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isTrue);

    await createService(db).ensureInstalled();

    expect(await db.geoDataDao.allRows, isEmpty);
    expect(await File(p.join(datRoot.path, 'custom.dat')).exists(), isFalse);
    expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isFalse);
  });

  test('startup finishes an import committed before cleanup', () async {
    await service.ensureInstalled();
    final draft = await service.prepareImports([input()]);
    await draft.publish();
    await db.transaction(draft.commit);

    await createService(db).ensureInstalled();

    expect((await db.geoDataDao.allRows).single.name, 'custom');
    expect(
      await File(p.join(datRoot.path, 'custom.dat')).readAsString(),
      'one',
    );
    expect(await File(p.join(datRoot.path, 'custom.json')).exists(), isTrue);
  });

  test('restore changes flat files only with its outer transaction', () async {
    await service.ensureInstalled();
    await service.add(input());
    final beforeRows = await db.geoDataDao.publishedRows;
    final beforeFiles = await rootBytes();
    final archive = Directory(p.join(workspace.path, 'archive'));
    await archive.create();
    await File(p.join(archive.path, 'custom.dat')).writeAsString('restored');
    await count(archive.path, 'custom', GeoDataType.domain);

    await File(p.join(archive.path, 'orphan.dat')).writeAsString('orphan');
    await count(archive.path, 'orphan', GeoDataType.domain);
    final invalid = await service.prepareRestore(archive.path);
    await expectLater(
      db.transaction(() async {
        await db.geoDataDao.clear();
        await db.geoDataDao.insertRow(
          GeoDataCompanion.insert(
            id: const Value(77),
            name: 'custom',
            type: 'domain',
            url: 'https://example.com/custom.dat',
            timestamp: DateTime(2020),
            categoryCount: 1,
            ruleCount: 2,
          ),
        );
        await invalid.commit();
      }),
      throwsFormatException,
    );
    await invalid.dispose();
    expect(await db.geoDataDao.publishedRows, beforeRows);
    expect(await rootBytes(), beforeFiles);
    await File(p.join(archive.path, 'orphan.dat')).delete();
    await File(p.join(archive.path, 'orphan.json')).delete();

    final draft = await service.prepareRestore(archive.path);
    await expectLater(
      db.transaction(() async {
        await db.geoDataDao.clear();
        await db.geoDataDao.insertRow(
          GeoDataCompanion.insert(
            id: const Value(77),
            name: 'custom',
            type: 'domain',
            url: 'https://example.com/custom.dat',
            timestamp: DateTime(2020),
            categoryCount: 1,
            ruleCount: 2,
          ),
        );
        await draft.commit();
        throw StateError('Restore interrupted');
      }),
      throwsStateError,
    );
    await draft.dispose();
    expect(await db.geoDataDao.publishedRows, beforeRows);
    expect(await rootBytes(), beforeFiles);
    await expectFlatRoot();

    final committed = await service.prepareRestore(archive.path);
    await db.transaction(() async {
      await db.geoDataDao.clear();
      await db.geoDataDao.insertRow(
        GeoDataCompanion.insert(
          id: const Value(77),
          name: 'custom',
          type: 'domain',
          url: 'https://example.com/custom.dat',
          timestamp: DateTime(2020),
          categoryCount: 1,
          ruleCount: 2,
        ),
      );
      await committed.commit();
    });
    await committed.complete();
    await committed.dispose();

    final files = await service.publishedFiles();
    expect(files.map((file) => file.data.parent.path).toSet(), {datRoot.path});
    expect(
      await files.firstWhere((file) => !file.builtIn).data.readAsString(),
      'restored',
    );
    expect((await db.geoDataDao.allRows).single.id, 77);
    await expectFlatRoot();
  });

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
