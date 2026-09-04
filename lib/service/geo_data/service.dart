import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/geo_data/download.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/geo_data/system_state.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/vpn/command_serial_executor.dart';
import 'package:path/path.dart' as p;

/// All installed Geodata lives directly in one flat directory. Downloads and
/// rollback backups use short-lived sibling directories only.
class GeoDataService {
  static final GeoDataService _singleton = GeoDataService._(
    null,
    null,
    downloadGeoData,
    _countNative,
    copyBundledTo,
    (value) => AppEventBus.instance.updateDownloading(value),
  );
  factory GeoDataService() => _singleton;
  GeoDataService._(
    this._database,
    this._directory,
    this._download,
    this._count,
    this._copyBundled,
    this._setDownloading,
  );

  factory GeoDataService.forTesting({
    required AppDatabase database,
    required String directory,
    required Future<void> Function(String, File) download,
    required Future<void> Function(String, String, GeoDataType) count,
    required Future<void> Function(String) copyBundled,
  }) => GeoDataService._(
    database,
    directory,
    download,
    count,
    copyBundled,
    (_) {},
  );

  final AppDatabase? _database;
  final String? _directory;
  final Future<void> Function(String, File) _download;
  final Future<void> Function(String, String, GeoDataType) _count;
  final Future<void> Function(String) _copyBundled;
  final void Function(bool) _setDownloading;
  final _commands = CommandSerialExecutor();
  AppDatabase get _db => _database ?? AppDatabase();
  String get _root => _directory ?? VpnConstants.datDir;

  static final _defaults =
      <({int id, String name, GeoDataType type, String url})>[
        (
          id: SystemGeoDatId.geoIp.id,
          name: SystemGeoDatName.geoIp.name,
          type: GeoDataType.ip,
          url: SystemGeoDatURL.geoIp.name,
        ),
        (
          id: SystemGeoDatId.geoSite.id,
          name: SystemGeoDatName.geoSite.name,
          type: GeoDataType.domain,
          url: SystemGeoDatURL.geoSite.name,
        ),
      ];
  static final _bundledNames = Assets.dat.values.map(p.basename).toSet();

  /// File publication is exclusive with connection preparation/start so the
  /// shared directory cannot change while a runtime consumes it.
  Future<T> _maintain<T>(
    Future<T> Function() action, {
    bool downloading = false,
  }) => DataMaintenance.exclusive(
    () => _commands.run((_) async {
      if (downloading) _setDownloading(true);
      try {
        return await action();
      } finally {
        if (downloading) _setDownloading(false);
      }
    }),
  );

  Future<T> _cleanup<T>(Future<T> Function() action) =>
      DataMaintenance.cleanup(() => _commands.run((_) => action()));

  Future<void> ensureInstalled() => _maintain(_ensureInstalled);

  Future<void> _ensureInstalled() async {
    await _ensureRoot();
    final rows = await _db.geoDataDao.publishedRows;
    _checkDefaultRows(rows);
    final defaults = rows.where((row) => row.id < 0).toList();
    if (defaults.isNotEmpty) {
      await _readAll(defaults);
      return;
    }

    if (rows.isNotEmpty) {
      throw StateError('Default routing data is incomplete');
    }
    final existing = await _flatNames(Directory(_root));
    if (existing.any((name) => !_bundledNames.contains(name))) {
      throw StateError('Unregistered routing data is present');
    }

    // No same-version migration or generation merge: a missing publication is
    // installed from bundled data as a new flat baseline.
    final stage = await _newStage('install-');
    _FlatFileChange? change;
    try {
      await _copyBundled(stage.path);
      for (final source in _defaults) {
        await _index(stage.path, source.name, source.type);
      }
      final timestamp = await _assetTimestamp(stage.path);
      change = await _applyFiles(await _stageFiles(stage));
      try {
        await _db.transaction(() async {
          final current = await _db.geoDataDao.publishedRows;
          _checkDefaultRows(current);
          if (current.any((row) => row.id < 0)) {
            throw StateError(
              'Default routing data changed during installation',
            );
          }
          await _publishDefaults(_root, timestamp);
        });
      } catch (_) {
        await change.rollback();
        rethrow;
      }
      await change.complete();
    } finally {
      if (change == null) await _deleteStage(stage);
    }
  }

  Future<List<PublishedGeoData>> publishedFiles() async =>
      _readAll(await _db.geoDataDao.publishedRows);

  Stream<List<PublishedGeoData>> watchPublished() =>
      _db.geoDataDao.publishedRowsStream.asyncMap(_readAll);

  Future<void> add(GeoDataInput input, {bool downloading = true}) {
    final normalized = GeoDataInput(
      fileName: GeoDataInput.canonicalFileName(input.fileName),
      type: input.type,
      url: input.url.trim(),
    );
    return _maintain(() async {
      final draft = await _prepareImports([
        normalized,
      ], disposeWithinMaintenance: true);
      try {
        await draft.commit();
      } finally {
        await draft.dispose();
      }
    }, downloading: downloading);
  }

  Future<void> updateDefaults({bool downloading = true}) => _maintain(() async {
    await _ensureInstalled();
    final stage = await _newStage('download-');
    _FlatFileChange? change;
    try {
      for (final source in _defaults) {
        await _download(
          source.url,
          File(p.join(stage.path, '${source.name}.dat')),
        );
        await _index(stage.path, source.name, source.type);
      }
      change = await _applyFiles(await _stageFiles(stage));
      try {
        await _db.transaction(() => _publishDefaults(_root, DateTime.now()));
      } catch (_) {
        await change.rollback();
        rethrow;
      }
      await change.complete();
    } finally {
      if (change == null) await _deleteStage(stage);
    }
  }, downloading: downloading);

  Future<void> updateCustom(GeoDataData original, {bool downloading = true}) =>
      _maintain(() async {
        if (original.id <= 0) {
          throw StateError('Default routing data updates together');
        }
        _checkName(original.name);
        GeoDataInput.httpsUri(original.url);
        final stage = await _newStage('download-');
        _FlatFileChange? change;
        try {
          await _download(
            original.url,
            File(p.join(stage.path, '${original.name}.dat')),
          );
          final index = await _index(
            stage.path,
            original.name,
            _type(original.type),
          );
          change = await _applyFiles(await _stageFiles(stage));
          try {
            await _db.transaction(() async {
              final current = await _db.geoDataDao.searchRow(original.id);
              if (current == null || current != original) {
                throw StateError('Routing data source changed during update');
              }
              if (!await _db.geoDataDao.updateRow(
                current.copyWith(
                  timestamp: DateTime.now(),
                  categoryCount: index.categoryCount!,
                  ruleCount: index.ruleCount!,
                ),
              )) {
                throw StateError('Routing data source is unavailable');
              }
            });
          } catch (_) {
            await change.rollback();
            rethrow;
          }
          await change.complete();
        } finally {
          if (change == null) await _deleteStage(stage);
        }
      }, downloading: downloading);

  Future<void> deleteGeoDat(GeoDataData row) => _maintain(() async {
    if (row.id <= 0) throw StateError('Default routing data cannot be deleted');
    _checkName(row.name);
    final change = await _applyFiles({
      '${row.name}.dat': null,
      '${row.name}.json': null,
    });
    try {
      await _db.transaction(() async {
        final current = await _db.geoDataDao.searchRow(row.id);
        if (current == null || current != row) {
          throw StateError('Routing data source changed before deletion');
        }
        if (await _db.geoDataDao.deleteRow(row.id) != 1) {
          throw StateError('Routing data source is unavailable');
        }
      });
    } catch (_) {
      await change.rollback();
      rethrow;
    }
    await change.complete();
  });

  /// Download and validate in a sibling directory, then install new files in
  /// the canonical root. The caller commits metadata with its configuration.
  Future<GeoDataImportDraft> prepareImports(
    List<GeoDataInput> inputs, {
    bool downloading = false,
  }) => _maintain(() => _prepareImports(inputs), downloading: downloading);

  Future<GeoDataImportDraft> _prepareImports(
    List<GeoDataInput> inputs, {
    bool disposeWithinMaintenance = false,
  }) async {
    if (inputs.isEmpty) {
      return GeoDataImportDraft(const [], () async {}, () async {});
    }
    final sources = List<GeoDataInput>.unmodifiable(inputs);
    for (final source in sources) {
      if (GeoDataInput.canonicalFileName(source.fileName) != source.fileName) {
        throw const FormatException('Geodata filename is not canonical');
      }
      GeoDataInput.httpsUri(source.url);
    }
    await _ensureRoot();
    await _checkConflicts(sources, checkFiles: true);
    final stage = await _newStage('download-');
    final indexes = <String, XrayGeoList>{};
    try {
      for (final source in sources) {
        await _download(source.url, File(p.join(stage.path, source.fileName)));
        indexes[source.name] = await _index(
          stage.path,
          source.name,
          source.type,
        );
      }
      await _checkConflicts(sources, checkFiles: true);
      final change = await _applyFiles(await _stageFiles(stage));
      await change.complete();
    } catch (_) {
      await _deleteStage(stage);
      rethrow;
    }

    var disposed = false;
    Future<void> dispose() async {
      if (disposed) return;
      disposed = true;
      final publishedNames = (await _db.geoDataDao.publishedRows)
          .map((row) => row.name.toLowerCase())
          .toSet();
      for (final source in sources) {
        if (publishedNames.contains(source.name.toLowerCase())) {
          continue;
        }
        for (final suffix in ['dat', 'json']) {
          final file = File(p.join(_root, '${source.name}.$suffix'));
          if (await file.exists()) await file.delete();
        }
      }
    }

    return GeoDataImportDraft(sources, () async {
      if (disposed) throw StateError('Routing data draft was disposed');
      await _db.transaction(() async {
        await _checkConflicts(sources, checkFiles: false);
        final timestamp = DateTime.now();
        for (final source in sources) {
          await _regularFile(File(p.join(_root, source.fileName)));
          await _readIndex(File(p.join(_root, '${source.name}.json')));
          final index = indexes[source.name]!;
          await _db.geoDataDao.insertRow(
            GeoDataCompanion.insert(
              name: source.name,
              type: source.type.name,
              url: source.url,
              timestamp: timestamp,
              categoryCount: index.categoryCount!,
              ruleCount: index.ruleCount!,
            ),
          );
        }
      });
    }, disposeWithinMaintenance ? dispose : () => _cleanup(dispose));
  }

  /// Full backup restore stages a flat replacement. [GeoDataRestoreDraft.commit]
  /// runs inside the database restore transaction; the caller accepts it only
  /// after that outer transaction succeeds.
  Future<GeoDataRestoreDraft> prepareRestore(String flatDatDirectory) async {
    final stage = await _newStage('restore-');
    try {
      await for (final entry in Directory(
        flatDatDirectory,
      ).list(followLinks: false)) {
        final name = p.basename(entry.path);
        if (name.endsWith('.dat') ||
            name.endsWith('.json') ||
            name == VpnConstants.systemGeoTimestamp) {
          await _copyFile(File(entry.path), File(p.join(stage.path, name)));
        }
      }
      await _copyBundled(stage.path);
      for (final source in _defaults) {
        await _index(stage.path, source.name, source.type);
      }
    } catch (_) {
      await _deleteStage(stage);
      rethrow;
    }

    _FlatFileChange? change;
    var accepted = false;
    var disposed = false;
    return GeoDataRestoreDraft(
      () async {
        if (disposed || change != null) {
          throw StateError('Routing data restore draft is unavailable');
        }
        await _db.transaction(() async {
          final rows = await _db.geoDataDao.allRows;
          final expected = {
            ..._bundledNames,
            for (final row in rows) '${row.name}.dat',
            for (final row in rows) '${row.name}.json',
          };
          final actual = await _flatNames(stage);
          if (actual.length != expected.length ||
              !actual.containsAll(expected)) {
            throw const FormatException('Unexpected routing data file');
          }
          for (final row in rows) {
            _checkName(row.name);
            final index = await _index(stage.path, row.name, _type(row.type));
            if (!await _db.geoDataDao.updateRow(
              row.copyWith(
                categoryCount: index.categoryCount!,
                ruleCount: index.ruleCount!,
              ),
            )) {
              throw StateError('Restored routing data is unavailable');
            }
          }
          await _publishDefaults(stage.path, await _assetTimestamp(stage.path));
          change = await _replaceAll(stage);
        });
      },
      () async {
        if (disposed || change == null) {
          throw StateError('Routing data restore was not committed');
        }
        accepted = true;
        await change!.complete();
      },
      () async {
        if (disposed) return;
        disposed = true;
        if (change == null) {
          await _deleteStage(stage);
        } else if (!accepted) {
          await change!.rollback();
        }
      },
    );
  }

  Future<bool> insertGeoDat(
    String name,
    GeoDataType type,
    String url, {
    bool showLoading = true,
    bool needDownload = true,
  }) async {
    if (!needDownload) return false;
    try {
      await add(
        GeoDataInput(fileName: name, type: type, url: url),
        downloading: showLoading,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateGeoDat(
    GeoDataData row, {
    bool updateDownloading = true,
  }) async {
    try {
      if (row.id < 0) {
        await updateDefaults(downloading: updateDownloading);
      } else {
        await updateCustom(row, downloading: updateDownloading);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshSystemGeoDat(
    List<GeoDataData> _, {
    bool updateDownloading = true,
  }) => updateDefaults(downloading: updateDownloading);

  Future<void> _publishDefaults(String directory, DateTime timestamp) async {
    final existing = await _db.geoDataDao.publishedRows;
    _checkDefaultRows(existing);
    for (final source in _defaults) {
      final index = await _readIndex(
        File(p.join(directory, '${source.name}.json')),
      );
      final old = existing.where((row) => row.id == source.id).firstOrNull;
      final next = GeoDataCompanion.insert(
        id: Value(source.id),
        name: source.name,
        type: source.type.name,
        url: source.url,
        timestamp: timestamp,
        categoryCount: index.categoryCount!,
        ruleCount: index.ruleCount!,
      );
      if (old == null) {
        await _db.geoDataDao.insertRow(next);
      } else if (!await _db.geoDataDao.updateRow(
        old.copyWith(
          timestamp: timestamp,
          categoryCount: index.categoryCount!,
          ruleCount: index.ruleCount!,
        ),
      )) {
        throw StateError('Default routing data is unavailable');
      }
    }
  }

  void _checkDefaultRows(List<GeoDataData> rows) {
    for (final row in rows) {
      final expected = _defaults
          .where((value) => value.id == row.id)
          .firstOrNull;
      if ((row.id <= 0 &&
              (expected == null ||
                  row.name != expected.name ||
                  row.type != expected.type.name)) ||
          (row.id > 0 &&
              {'geoip', 'geosite'}.contains(row.name.toLowerCase()))) {
        throw StateError('Reserved routing data identity is occupied');
      }
    }
    final defaults = rows.where((row) => row.id < 0).toList();
    if (defaults.isNotEmpty && defaults.length != 2) {
      throw StateError('Default routing data is incomplete');
    }
  }

  Future<List<PublishedGeoData>> _readAll(List<GeoDataData> rows) async {
    await _ensureRoot();
    _checkDefaultRows(rows);
    final result = <PublishedGeoData>[];
    for (final row in rows) {
      _checkName(row.name);
      final data = File(p.join(_root, '${row.name}.dat'));
      final index = File(p.join(_root, '${row.name}.json'));
      await _regularFile(data);
      result.add(
        PublishedGeoData(
          row: row,
          data: data,
          indexFile: index,
          index: await _readIndex(index),
          bytes: await data.length(),
        ),
      );
    }
    return result;
  }

  Future<void> _checkConflicts(
    List<GeoDataInput> sources, {
    required bool checkFiles,
  }) async {
    final names = <String>{};
    final files = <String>{};
    for (final source in sources) {
      if (!names.add(source.name.toLowerCase())) {
        throw const FormatException('Duplicate Geodata filename');
      }
      files.addAll({
        source.fileName.toLowerCase(),
        '${source.name}.json'.toLowerCase(),
      });
    }
    final rows = await _db.geoDataDao.publishedRows;
    if (rows.any((row) => names.contains(row.name.toLowerCase()))) {
      throw const FormatException('Geodata filename already exists');
    }
    if (checkFiles) {
      for (final name in await _flatNames(Directory(_root))) {
        if (files.contains(name.toLowerCase())) {
          throw const FormatException('Geodata filename already exists');
        }
      }
    }
  }

  Future<void> _ensureRoot() async {
    if (_root.isEmpty) {
      throw StateError('Routing data directory is unavailable');
    }
    final root = Directory(_root);
    await root.create(recursive: true);
    await _flatNames(root);
  }

  Future<Directory> _newStage(String prefix) async {
    if (_root.isEmpty) {
      throw StateError('Routing data directory is unavailable');
    }
    final parent = Directory(p.dirname(_root));
    await parent.create(recursive: true);
    return parent.createTemp('.onexray-geodata-$prefix');
  }

  Future<Map<String, File?>> _stageFiles(Directory stage) async => {
    for (final name in await _flatNames(stage))
      name: File(p.join(stage.path, name)),
  };

  Future<_FlatFileChange> _replaceAll(Directory stage) async {
    await _ensureRoot();
    final replacements = <String, File?>{
      for (final name in await _flatNames(Directory(_root))) name: null,
      ...await _stageFiles(stage),
    };
    return _applyFiles(replacements);
  }

  Future<_FlatFileChange> _applyFiles(Map<String, File?> replacements) async {
    await _ensureRoot();
    final backup = await _newStage('backup-');
    final changed = _FlatFileChange(
      root: Directory(_root),
      backup: backup,
      sources: {
        for (final entry in replacements.entries)
          entry.key: entry.value?.parent,
      },
    );
    try {
      for (final entry in replacements.entries) {
        _checkFileName(entry.key);
        final target = File(p.join(_root, entry.key));
        final type = await FileSystemEntity.type(
          target.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.file) {
          await target.rename(p.join(backup.path, entry.key));
          changed.backedUp.add(entry.key);
        } else if (type != FileSystemEntityType.notFound) {
          throw StateError('Invalid routing data file');
        }
        final source = entry.value;
        if (source != null) {
          await _regularFile(source);
          await source.rename(target.path);
          changed.installed.add(entry.key);
        }
      }
      return changed;
    } catch (_) {
      await changed.rollback();
      rethrow;
    }
  }

  Future<XrayGeoList> _index(
    String directory,
    String name,
    GeoDataType type,
  ) async {
    final data = File(p.join(directory, '$name.dat'));
    await _regularFile(data);
    await _count(directory, name, type);
    final file = File(p.join(directory, '$name.json'));
    final index = await _readIndex(file);
    await file.writeAsString(jsonEncode(index.toJson()), flush: true);
    return index;
  }

  Future<XrayGeoList> _readIndex(File file) async {
    await _regularFile(file, limit: 32 * 1024 * 1024);
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid Geodata index');
    }
    final index = XrayGeoList.fromJson(value);
    if ((index.categoryCount ?? 0) <= 0 ||
        (index.ruleCount ?? 0) <= 0 ||
        index.codes == null ||
        index.codes!.isEmpty ||
        index.codes!.any(
          (entry) =>
              entry.code == null ||
              entry.code!.isEmpty ||
              (entry.ruleCount ?? -1) < 0,
        )) {
      throw const FormatException('Invalid Geodata index');
    }
    return index;
  }

  static Future<Set<String>> _flatNames(Directory directory) async {
    if (!await directory.exists()) return {};
    final names = <String>{};
    await for (final entry in directory.list(followLinks: false)) {
      if (await FileSystemEntity.type(entry.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('Routing data directory must be flat');
      }
      final name = p.basename(entry.path);
      _checkFileName(name);
      names.add(name);
    }
    return names;
  }

  static Future<void> _regularFile(
    File file, {
    int limit = 512 * 1024 * 1024,
  }) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Routing data file is unavailable');
    }
    final length = await file.length();
    if (length <= 0 || length > limit) {
      throw const FormatException('Invalid routing data file size');
    }
  }

  static Future<void> _copyFile(File source, File target) async {
    await _regularFile(source);
    final sink = target.openWrite();
    try {
      await sink.addStream(source.openRead());
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<void> _deleteStage(Directory stage) async {
    final expectedParent = p.normalize(p.dirname(_root));
    if (p.normalize(p.dirname(stage.path)) != expectedParent ||
        !p.basename(stage.path).startsWith('.onexray-geodata-')) {
      throw StateError('Invalid Geodata staging directory');
    }
    if (await stage.exists()) await stage.delete(recursive: true);
  }

  static void _checkFileName(String name) {
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        p.posix.basename(name) != name ||
        p.windows.basename(name) != name ||
        name.contains(RegExp(r'[\\/:\x00-\x1f\x7f]'))) {
      throw const FormatException('Invalid routing data filename');
    }
  }

  static void _checkName(String name) => _checkFileName(name);

  static GeoDataType _type(String type) => GeoDataType.values.firstWhere(
    (value) => value.name == type,
    orElse: () => throw const FormatException('Invalid Geodata type'),
  );

  static Future<DateTime> _assetTimestamp(String directory) async {
    final file = File(p.join(directory, VpnConstants.systemGeoTimestamp));
    if (await file.exists()) {
      await _regularFile(file, limit: 64);
      final seconds = int.tryParse((await file.readAsString()).trim());
      if (seconds != null && seconds > 0) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return File(p.join(directory, 'geoip.dat')).lastModified();
  }

  static Future<void> _countNative(
    String directory,
    String name,
    GeoDataType type,
  ) async {
    final error = await AppHostApi().countGeoData(
      CountGeoDataRequest(name, type.name, datDir: directory),
    );
    if (error.isNotEmpty) throw const FormatException('Geodata parsing failed');
  }

  static Future<void> copyBundledTo(String destination) async {
    await Directory(destination).create(recursive: true);
    for (final asset in Assets.dat.values) {
      final data = await rootBundle.load(asset);
      await File(p.join(destination, p.basename(asset))).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
  }
}

final class _FlatFileChange {
  final Directory root;
  final Directory backup;
  final Map<String, Directory?> sources;
  final Set<String> backedUp = {};
  final Set<String> installed = {};
  bool _finished = false;

  _FlatFileChange({
    required this.root,
    required this.backup,
    required this.sources,
  });

  Future<void> rollback() async {
    if (_finished) return;
    await root.create(recursive: true);
    for (final name in installed) {
      final current = File(p.join(root.path, name));
      if (await current.exists()) await current.delete();
    }
    for (final name in backedUp) {
      final previous = File(p.join(backup.path, name));
      if (await previous.exists()) {
        await previous.rename(p.join(root.path, name));
      }
    }
    _finished = true;
    await _cleanup();
  }

  Future<void> complete() async {
    if (_finished) return;
    _finished = true;
    await _cleanup();
  }

  Future<void> _cleanup() async {
    if (await backup.exists()) await backup.delete(recursive: true);
    for (final directory in sources.values.whereType<Directory>().toSet()) {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }
}
