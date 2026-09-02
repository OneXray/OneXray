import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late AppDatabase db;
  late GeoDataService service;
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

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('onexray-geodata-');
    addTearDown(() => directory.delete(recursive: true));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    revision = 'one';
    failDownload = null;
    failIndex = null;
    downloads = 0;
    service = GeoDataService.forTesting(
      database: db,
      directory: directory.path,
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

  test('local install publishes both defaults together, without networking or backup rows', () async {
    await service.ensureInstalled();
    final files = await service.publishedFiles();
    expect(downloads, 0);
    expect(files.map((file) => file.row.id).toSet(), {-1, -2});
    expect(files.map((file) => file.row.generation).toSet(), hasLength(1));
    expect(files.every((file) => file.row.generation != null), isTrue);
    expect(await db.geoDataDao.allRows, isEmpty);
    expect(
      files.every(
        (file) => file.row.timestamp.millisecondsSinceEpoch == 123000,
      ),
      isTrue,
    );
    await service.ensureInstalled();
    expect(
      await db.geoDataDao.publishedRows,
      files.map((file) => file.row).toList(),
    );
  });

  test('legacy default bytes and custom basename stay unchanged', () async {
    for (final name in ['geoip', 'geosite', 'legacy.dat']) {
      await File(p.join(directory.path, '$name.dat')).writeAsString('legacy');
      await count(directory.path, name, GeoDataType.domain);
    }
    await db.geoDataDao.insertRow(
      GeoDataCompanion.insert(
        id: const Value(9),
        name: 'legacy.dat',
        type: 'domain',
        url: 'https://example.com/legacy',
        timestamp: DateTime(2020),
        categoryCount: 1,
        ruleCount: 2,
      ),
    );
    await service.ensureInstalled();
    final legacy = (await db.geoDataDao.allRows).single;
    expect(legacy.name, 'legacy.dat');
    expect(legacy.generation, isNull);
    final files = await service.publishedFiles();
    expect(
      await files.firstWhere((file) => file.builtIn).data.readAsString(),
      'legacy',
    );
    final copy = await directory.createTemp('plan-');
    await service.copyPublishedTo(copy.path);
    expect(
      await File(p.join(copy.path, 'legacy.dat.dat')).readAsString(),
      'legacy',
    );
    expect(
      (await service.readGeoList(directory.path, 'geosite')).categoryCount,
      1,
    );
  });

  test('either default download or index failure leaves both published rows untouched', () async {
    await service.ensureInstalled();
    final before = await db.geoDataDao.publishedRows;
    failDownload = 'geosite';
    await expectLater(
      service.updateDefaults(),
      throwsA(isA<SocketException>()),
    );
    expect(await db.geoDataDao.publishedRows, before);
    failDownload = null;
    failIndex = 'geosite';
    await expectLater(service.updateDefaults(), throwsFormatException);
    expect(await db.geoDataDao.publishedRows, before);
    failIndex = null;
    await service.updateDefaults();
    final after = await service.publishedFiles();
    expect(after.map((file) => file.row.generation).toSet(), hasLength(1));
    expect(after.first.row.generation, isNot(before.first.generation));
  });

  test('DB failure does not publish prepared bytes, and old plan copies remain valid', () async {
    await service.ensureInstalled();
    await service.add(input());
    final old = (await service.publishedFiles()).firstWhere(
      (file) => !file.builtIn,
    );
    final plan = await directory.createTemp('plan-');
    await service.copyPublishedTo(plan.path);
    await db.customStatement(
      "CREATE TRIGGER fail_geo_update BEFORE UPDATE ON geo_data WHEN OLD.id > 0 BEGIN SELECT RAISE(FAIL, 'fixture'); END",
    );
    revision = 'two';
    await expectLater(service.updateCustom(old.row), throwsA(anything));
    expect(await db.geoDataDao.searchRow(old.row.id), old.row);
    expect(await old.data.readAsString(), 'one');
    expect(await File(p.join(plan.path, 'custom.dat')).readAsString(), 'one');
    await db.customStatement('DROP TRIGGER fail_geo_update');
    await service.updateCustom(old.row);
    final fresh = (await service.publishedFiles()).firstWhere(
      (file) => !file.builtIn,
    );
    expect(await fresh.data.readAsString(), 'two');
    expect(await old.data.readAsString(), 'one');
    await service.deleteGeoDat(fresh.row);
    expect(await fresh.data.readAsString(), 'two');
    expect(await File(p.join(plan.path, 'custom.dat')).readAsString(), 'one');
  });

  test('dependency draft shares the caller transaction and rejects conflicts before downloading', () async {
    await service.ensureInstalled();
    final draft = await service.prepareImports([input()]);
    expect(await db.geoDataDao.allRows, isEmpty);
    final validation = await directory.createTemp('validation-');
    await draft.copyFilesTo(validation.path);
    expect(
      await File(p.join(validation.path, 'custom.dat')).readAsString(),
      'one',
    );
    await expectLater(
      db.transaction(() async {
        await draft.commit();
        throw StateError('Config save failed');
      }),
      throwsStateError,
    );
    await draft.dispose();
    expect(await db.geoDataDao.allRows, isEmpty);
    await service.add(input());
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
  });

  test(
    'restore replaces same-name data only with its database transaction',
    () async {
      await service.ensureInstalled();
      await service.add(input());
      final before = await db.geoDataDao.publishedRows;
      final archive = await directory.createTemp('archive-');
      await File(p.join(archive.path, 'custom.dat')).writeAsString('restored');
      await count(archive.path, 'custom', GeoDataType.domain);
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
      expect(await db.geoDataDao.publishedRows, before);
      await draft.dispose();
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
      await committed.dispose();
      final files = await service.publishedFiles();
      expect(files.map((file) => file.row.generation).toSet(), hasLength(1));
      expect(
        await files.firstWhere((file) => !file.builtIn).data.readAsString(),
        'restored',
      );
    },
  );

  test('reserved IDs never overwrite historical records', () async {
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
  });
}
