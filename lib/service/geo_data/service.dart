import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

/// SQLite rows are the only publication pointer. A generation is sealed before
/// its rows are committed; readers never infer publication from files or dates.
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
  String get _generations => p.join(_root, 'generations');

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

  Future<T> _maintain<T>(
    Future<T> Function() action, {
    bool downloading = false,
  }) => DataMaintenance.run(
    () => _commands.run((_) async {
      if (downloading) _setDownloading(true);
      try {
        return await action();
      } finally {
        if (downloading) _setDownloading(false);
      }
    }),
  );

  /// No network. Preserve a valid legacy default pair, or seed bundled assets.
  /// Database upgrades never create these rows or touch data files.
  Future<void> ensureInstalled() => _maintain(_ensureInstalled);

  Future<void> _ensureInstalled() async {
    final rows = await _db.geoDataDao.publishedRows;
    _checkDefaultRows(rows);
    final defaults = rows.where((row) => row.id < 0).toList();
    if (defaults.isNotEmpty) {
      await _readAll(defaults);
      return;
    }
    final stage = await _newStage();
    Directory? sealed;
    var attempted = false;
    try {
      try {
        for (final source in _defaults) {
          await _copyFile(
            File(p.join(_root, '${source.name}.dat')),
            File(p.join(stage.path, '${source.name}.dat')),
          );
          await _index(stage.path, source.name, source.type);
        }
        final stamp = File(p.join(_root, VpnConstants.systemGeoTimestamp));
        if (await stamp.exists()) {
          await _copyFile(
            stamp,
            File(p.join(stage.path, VpnConstants.systemGeoTimestamp)),
          );
        }
      } catch (_) {
        await _copyBundled(stage.path);
        for (final source in _defaults) {
          await _index(stage.path, source.name, source.type);
        }
      }
      sealed = await _seal(stage);
      final timestamp = await _assetTimestamp(sealed.path);
      attempted = true;
      await _db.transaction(() async {
        final current = await _db.geoDataDao.publishedRows;
        _checkDefaultRows(current);
        if (current.any((row) => row.id < 0)) return;
        await _publishDefaults(sealed!, timestamp);
      });
    } finally {
      await _disposeStage(stage, sealed, attempted: attempted);
    }
  }

  Future<List<PublishedGeoData>> publishedFiles() async =>
      _readAll(await _db.geoDataDao.publishedRows);

  Stream<List<PublishedGeoData>> watchPublished() =>
      _db.geoDataDao.publishedRowsStream.asyncMap(_readAll);

  /// One row snapshot, then immutable copies. Updates/deletes cannot invalidate
  /// an in-flight plan copy, and the default pair never straddles two versions.
  Future<void> copyPublishedTo(String destination) async {
    final files = await publishedFiles();
    if (files.where((file) => file.builtIn).length != 2) {
      throw StateError('Default routing data is not installed');
    }
    await Directory(destination).create(recursive: true);
    for (final file in files) {
      await _copyFile(file.data, File(p.join(destination, file.fileName)));
      await _copyFile(
        file.indexFile,
        File(p.join(destination, '${file.row.name}.json')),
      );
    }
  }

  Future<XrayGeoList> readGeoList(String datDir, String name) async {
    _checkName(name);
    var directory = datDir;
    if (p.normalize(datDir) == p.normalize(_root)) {
      final row = await _db.geoDataDao.searchRowByName(name);
      if (row != null) directory = _rowDirectory(row);
    }
    final file = File(p.join(directory, '$name.json'));
    if (!await file.exists()) return XrayGeoList(null, null, null);
    return _readIndex(file);
  }

  Future<void> add(GeoDataInput input, {bool downloading = true}) =>
      _maintain(() async {
        final normalized = GeoDataInput(
          fileName: GeoDataInput.canonicalFileName(input.fileName),
          type: input.type,
          url: input.url.trim(),
        );
        final draft = await prepareImports([normalized]);
        try {
          await draft.commit();
        } finally {
          await draft.dispose();
        }
      }, downloading: downloading);

  Future<void> updateDefaults({bool downloading = true}) => _maintain(() async {
    await _ensureInstalled();
    final stage = await _newStage();
    Directory? sealed;
    var attempted = false;
    try {
      for (final source in _defaults) {
        await _download(
          source.url,
          File(p.join(stage.path, '${source.name}.dat')),
        );
        await _index(stage.path, source.name, source.type);
      }
      sealed = await _seal(stage);
      attempted = true;
      await _db.transaction(() => _publishDefaults(sealed!, DateTime.now()));
    } finally {
      await _disposeStage(stage, sealed, attempted: attempted);
    }
  }, downloading: downloading);

  Future<void> updateCustom(GeoDataData original, {bool downloading = true}) =>
      _maintain(() async {
        if (original.id <= 0) {
          throw StateError('Default routing data updates together');
        }
        _checkName(original.name);
        GeoDataInput.httpsUri(original.url);
        final stage = await _newStage();
        Directory? sealed;
        var attempted = false;
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
          sealed = await _seal(stage);
          attempted = true;
          await _db.transaction(() async {
            final current = await _db.geoDataDao.searchRow(original.id);
            if (current == null || current != original) {
              throw StateError('Routing data source changed during update');
            }
            await _db.geoDataDao.updateRow(
              current.copyWith(
                timestamp: DateTime.now(),
                categoryCount: index.categoryCount!,
                ruleCount: index.ruleCount!,
                generation: Value(p.basename(sealed!.path)),
              ),
            );
          });
        } finally {
          await _disposeStage(stage, sealed, attempted: attempted);
        }
      }, downloading: downloading);

  Future<void> deleteGeoDat(GeoDataData row) => _maintain(() async {
    if (row.id <= 0) throw StateError('Default routing data cannot be deleted');
    await _db.geoDataDao.deleteRow(row.id);
    // Old generations and legacy files remain readable by existing plans.
  });

  /// Download/parse only. Caller commits dependencies and configuration in one
  /// database transaction. Filenames must already match their ext: references.
  Future<GeoDataImportDraft> prepareImports(List<GeoDataInput> inputs) async {
    if (inputs.isEmpty) {
      return GeoDataImportDraft(
        const [],
        () async {},
        () async {},
        (_) async {},
      );
    }
    final sources = List<GeoDataInput>.unmodifiable(inputs);
    for (final source in sources) {
      if (GeoDataInput.canonicalFileName(source.fileName) != source.fileName) {
        throw const FormatException('Geodata filename is not canonical');
      }
      GeoDataInput.httpsUri(source.url);
    }
    await _checkConflicts(sources);
    final stage = await _newStage();
    Directory? sealed;
    var attempted = false;
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
      sealed = await _seal(stage);
    } catch (_) {
      await _disposeStage(stage, sealed, attempted: false);
      rethrow;
    }
    var disposed = false;
    return GeoDataImportDraft(
      sources,
      () async {
        if (disposed) throw StateError('Routing data draft was disposed');
        attempted = true;
        await _db.transaction(() async {
          await _checkConflicts(sources);
          final timestamp = DateTime.now();
          for (final source in sources) {
            final index = indexes[source.name]!;
            await _db.geoDataDao.insertRow(
              GeoDataCompanion.insert(
                name: source.name,
                type: source.type.name,
                url: source.url,
                timestamp: timestamp,
                categoryCount: index.categoryCount!,
                ruleCount: index.ruleCount!,
                generation: Value(p.basename(sealed!.path)),
              ),
            );
          }
        });
      },
      () async {
        disposed = true;
        await _disposeStage(stage, sealed, attempted: attempted);
      },
      (destination) async {
        if (disposed) throw StateError('Routing data draft was disposed');
        await Directory(destination).create(recursive: true);
        for (final source in sources) {
          for (final suffix in ['dat', 'json']) {
            await _copyFile(
              File(p.join(sealed!.path, '${source.name}.$suffix')),
              File(p.join(destination, '${source.name}.$suffix')),
            );
          }
        }
      },
    );
  }

  /// Full backup restore: stage custom files plus bundled defaults. Call commit
  /// AFTER restored metadata is inserted, in the same outer transaction. This
  /// intentionally does not apply ordinary-import filename conflicts.
  Future<GeoDataRestoreDraft> prepareRestore(String flatDatDirectory) async {
    final stage = await _newStage();
    Directory? sealed;
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
      sealed = await _seal(stage);
    } catch (_) {
      await _disposeStage(stage, sealed, attempted: false);
      rethrow;
    }
    var attempted = false;
    var disposed = false;
    return GeoDataRestoreDraft(
      () async {
        if (disposed) {
          throw StateError('Routing data restore draft was disposed');
        }
        attempted = true;
        await _db.transaction(() async {
          final rows = await _db.geoDataDao.allRows;
          for (final row in rows) {
            _checkName(row.name);
            final index = await _index(sealed!.path, row.name, _type(row.type));
            await _db.geoDataDao.updateRow(
              row.copyWith(
                categoryCount: index.categoryCount!,
                ruleCount: index.ruleCount!,
                generation: Value(p.basename(sealed!.path)),
              ),
            );
          }
          await _publishDefaults(sealed!, await _assetTimestamp(sealed.path));
        });
      },
      () async {
        disposed = true;
        await _disposeStage(stage, sealed, attempted: attempted);
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
    // Legacy link import facade. Local import is not restored; portable backup
    // uses its separate full-restore transaction.
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

  Future<void> _publishDefaults(Directory directory, DateTime timestamp) async {
    final existing = await _db.geoDataDao.publishedRows;
    _checkDefaultRows(existing);
    for (final source in _defaults) {
      final index = await _readIndex(
        File(p.join(directory.path, '${source.name}.json')),
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
        generation: Value(p.basename(directory.path)),
      );
      if (old == null) {
        await _db.geoDataDao.insertRow(next);
      } else {
        await _db.geoDataDao.updateRow(
          old.copyWith(
            timestamp: timestamp,
            categoryCount: index.categoryCount!,
            ruleCount: index.ruleCount!,
            generation: next.generation,
          ),
        );
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
    if (defaults.isNotEmpty &&
        (defaults.length != 2 ||
            defaults[0].generation != defaults[1].generation)) {
      throw StateError('Default routing data is not a complete generation');
    }
  }

  Future<List<PublishedGeoData>> _readAll(List<GeoDataData> rows) async {
    _checkDefaultRows(rows);
    final result = <PublishedGeoData>[];
    for (final row in rows) {
      final directory = _rowDirectory(row);
      final data = File(p.join(directory, '${row.name}.dat'));
      final index = File(p.join(directory, '${row.name}.json'));
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

  String _rowDirectory(GeoDataData row) {
    _checkName(row.name);
    final generation = row.generation;
    if (generation == null) return _root;
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(generation)) {
      throw StateError('Invalid routing data generation');
    }
    return p.join(_generations, generation);
  }

  Future<void> _checkConflicts(List<GeoDataInput> sources) async {
    final names = <String>{};
    for (final source in sources) {
      if (!names.add(source.fileName.toLowerCase())) {
        throw const FormatException('Duplicate Geodata filename');
      }
    }
    final rows = await _db.geoDataDao.publishedRows;
    if (rows.any((row) => names.contains('${row.name}.dat'.toLowerCase()))) {
      throw const FormatException('Geodata filename already exists');
    }
    if (await Directory(_root).exists()) {
      await for (final entry in Directory(_root).list(followLinks: false)) {
        if (names.contains(p.basename(entry.path).toLowerCase())) {
          throw const FormatException('Geodata filename already exists');
        }
      }
    }
  }

  Future<Directory> _newStage() async {
    if (_root.isEmpty) {
      throw StateError('Routing data directory is unavailable');
    }
    await Directory(_generations).create(recursive: true);
    if (await FileSystemEntity.type(_generations, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('Invalid routing data directory');
    }
    return Directory(_generations).createTemp('stage-');
  }

  Future<Directory> _seal(Directory stage) async {
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return stage.rename(p.join(_generations, id));
  }

  Future<void> _disposeStage(
    Directory stage,
    Directory? sealed, {
    required bool attempted,
  }) async {
    final directory = sealed ?? stage;
    // ponytail: retain attempted publications, including rollback orphans. A DB
    // reference check alone races a plan copying an old row snapshot. Safe GC
    // can follow later; do not build a reference-counting service here.
    if (attempted) return;
    if (p.dirname(directory.path) != _generations) {
      throw StateError('Invalid draft directory');
    }
    if (await FileSystemEntity.type(directory.path, followLinks: false) ==
        FileSystemEntityType.directory) {
      await directory.delete(recursive: true);
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

  static void _checkName(String name) {
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        p.posix.basename(name) != name ||
        p.windows.basename(name) != name ||
        name.contains(RegExp(r'[\\/:\x00-\x1f\x7f]'))) {
      throw const FormatException('Invalid routing data basename');
    }
  }

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
