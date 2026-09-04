import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/data_cleanup/service.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/share/backup_archive.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:onexray/service/share/backup_database.dart';
import 'package:onexray/service/share/backup_model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// 文件结构
// OneXray-date.zip
// -- manifest.json
// -- core_configs.json
// -- subscriptions.json
// -- geo_data.json
// -- routing_profile.json
// -- dat
//    -- geo.dat
//    -- geo.json

class BackupService {
  static final BackupService _singleton = BackupService._internal();

  factory BackupService() => _singleton;

  BackupService._internal();

  static const _backupVersion = BackupManifestJson.currentVersion;
  static const _datDir = "dat";
  static const _manifestFile = "manifest.json";
  static const _coreConfigsFile = "core_configs.json";
  static const _subscriptionsFile = "subscriptions.json";
  static const _geoDataFile = "geo_data.json";
  static const _routingProfileFile = "routing_profile.json";

  int _lastRestoreSkippedCoreConfigCount = 0;
  static const _zipFilePrefix = "OneXray";

  // backup zip files dir, in application support directory
  static const _backupName = "backup";
  static const _archiveExtractor = BackupArchiveExtractor(
    rootFiles: {
      _manifestFile,
      _coreConfigsFile,
      _subscriptionsFile,
      _geoDataFile,
      _routingProfileFile,
    },
    dataDirectory: _datDir,
  );

  Future<String> get backupDir async {
    final rootPath = await getApplicationSupportDirectory();
    final backupPath = p.join(rootPath.path, _backupName);
    await FileTool.checkDir(backupPath);
    return backupPath;
  }

  /// Null means the system picker was cancelled, not a failed import.
  Future<bool?> importBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ["zip"],
    );
    if (file == null) {
      return null;
    }
    final path = file.path;
    if (path == null) {
      return false;
    }

    final cacheDir = await FileTool.makeCacheDir();
    try {
      final payload = await _readBackupPayload(path, cacheDir);
      if (payload == null) {
        return false;
      }
      await _saveBackupFile(path, payload.createdAt);
      return true;
    } finally {
      await FileTool.deleteDirIfExists(cacheDir);
    }
  }

  Future<void> backup() => DataMaintenance.exclusive(_backup);

  Future<void> _backup() async {
    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);

    final cacheDir = await FileTool.makeCacheDir();
    final stagingDir = p.join(cacheDir, "staging");
    final createdAt = DateTime.now();
    try {
      final contents = await BackupDatabaseContents.read(AppDatabase());
      contents.validate();
      await FileTool.checkDir(stagingDir);
      await _writeManifest(stagingDir, createdAt);
      await _backupGeoData(stagingDir, contents.geoDataList);
      await _writeJsonToFile(
        contents.coreConfigs,
        p.join(stagingDir, _coreConfigsFile),
      );
      await _writeJsonToFile(
        contents.subscriptions,
        p.join(stagingDir, _subscriptionsFile),
      );
      await _writeJsonToFile(
        contents.routingProfiles,
        p.join(stagingDir, _routingProfileFile),
      );

      final zipSrcPath = p.join(cacheDir, "$_zipFilePrefix.zip");
      await _archiveDirToZipFile(stagingDir, zipSrcPath);
      await _saveBackupFile(zipSrcPath, createdAt);
    } catch (e, stackTrace) {
      ygLogger("backup error (${e.runtimeType})\n$stackTrace");
      rethrow;
    } finally {
      await FileTool.deleteDirIfExists(cacheDir);
      eventBus.updateDownloading(false);
    }
  }

  Future<bool> restore(String zipPath) async {
    List<SubscriptionData> legacySubscriptions = const [];
    final success = await DataMaintenance.exclusive(() async {
      _lastRestoreSkippedCoreConfigCount = 0;
      final eventBus = AppEventBus.instance;
      eventBus.updateDownloading(true);

      final cacheDir = await FileTool.makeCacheDir();
      GeoDataRestoreDraft? datRestore;
      try {
        final payload = await _readBackupPayload(zipPath, cacheDir);
        if (payload == null) {
          return false;
        }

        final cleanupService = AppDataCleanupService();
        if (!await cleanupService.prepareForBackupRestore()) {
          return false;
        }

        final datDirectory = p.join(payload.rootDir, _datDir);
        await Directory(datDirectory).create(recursive: true);
        datRestore = await GeoDataService().prepareRestore(datDirectory);
        final database = AppDatabase();
        final subscriptions = await database.transaction(() async {
          final rows = await payload.contents.restore(database);
          await datRestore!.commit();
          return rows;
        });
        if (payload.contents.version < _backupVersion) {
          legacySubscriptions = subscriptions;
        }
        _lastRestoreSkippedCoreConfigCount =
            payload.contents.skippedCoreConfigCount;
        if (_lastRestoreSkippedCoreConfigCount > 0) {
          ygLogger(
            'backup restore skipped $_lastRestoreSkippedCoreConfigCount retired configs',
          );
        }
        return true;
      } catch (e, stackTrace) {
        ygLogger("restore backup error (${e.runtimeType})\n$stackTrace");
        return false;
      } finally {
        await datRestore?.dispose();
        await FileTool.deleteDirIfExists(cacheDir);
        eventBus.updateDownloading(false);
      }
    });
    // Legacy ZIPs have no subscription cache. Refresh only after maintenance
    // releases its gate, so ordinary subscription writes do not re-enter it.
    if (success && legacySubscriptions.isNotEmpty) {
      await _refreshRestoredSubscriptions(legacySubscriptions);
    }
    return success;
  }

  Future<_BackupPayload?> _readBackupPayload(
    String zipPath,
    String cacheDir,
  ) async {
    try {
      await _archiveExtractor.extract(zipPath, cacheDir);
      return await _readBackupDir(cacheDir);
    } catch (e, stackTrace) {
      ygLogger("read backup error (${e.runtimeType})\n$stackTrace");
      return null;
    }
  }

  Future<_BackupPayload?> _readBackupDir(String backupRoot) async {
    final manifest = await _readManifest(backupRoot);
    if (manifest == null) {
      return null;
    }

    final coreConfigs = await _readJsonList(
      p.join(backupRoot, _coreConfigsFile),
      BackupCoreConfigJson.fromJson,
    );
    final subscriptions = await _readJsonList(
      p.join(backupRoot, _subscriptionsFile),
      BackupSubscriptionJson.fromJson,
    );
    final geoDataList = await _readJsonList(
      p.join(backupRoot, _geoDataFile),
      BackupGeoDataJson.fromJson,
    );
    final routingFile = p.join(backupRoot, _routingProfileFile);
    final routingProfiles = manifest.version == _backupVersion
        ? await _readJsonList(routingFile, BackupRoutingProfileJson.fromJson)
        : <BackupRoutingProfileJson>[];
    if (coreConfigs == null ||
        subscriptions == null ||
        geoDataList == null ||
        routingProfiles == null ||
        (manifest.version != _backupVersion &&
            await File(routingFile).exists())) {
      return null;
    }

    final contents = BackupDatabaseContents(
      version: manifest.version!,
      coreConfigs: coreConfigs,
      subscriptions: subscriptions,
      geoDataList: geoDataList,
      routingProfiles: routingProfiles,
    );
    contents.validate();
    if (!await _validateGeoDataList(backupRoot, geoDataList)) {
      return null;
    }

    return _BackupPayload(
      rootDir: backupRoot,
      createdAt: DateTime.fromMillisecondsSinceEpoch(manifest.createdAt!),
      contents: contents,
    );
  }

  Future<BackupManifestJson?> _readManifest(String backupRoot) async {
    final manifestFile = File(p.join(backupRoot, _manifestFile));
    if (!await manifestFile.exists()) {
      return null;
    }

    final manifest = await _readJsonModel(
      manifestFile.path,
      BackupManifestJson.fromJson,
    );
    if (manifest == null ||
        !BackupManifestJson.supportedVersions.contains(manifest.version) ||
        manifest.createdAt == null) {
      return null;
    }
    return manifest;
  }

  Future<T?> _readJsonModel<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<List<T>?> _readJsonList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! List) {
        return null;
      }

      final models = <T>[];
      for (final item in data) {
        if (item is! Map<String, dynamic>) {
          return null;
        }
        models.add(fromJson(item));
      }
      return models;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _validateGeoDataList(
    String backupRoot,
    List<BackupGeoDataJson> geoDataList,
  ) async {
    final datDir = p.join(backupRoot, _datDir);
    for (final geoData in geoDataList) {
      final name = geoData.name!;
      final datFile = File(p.join(datDir, "$name.dat"));
      final jsonFile = File(p.join(datDir, "$name.json"));
      if (!await datFile.exists() || !await jsonFile.exists()) {
        return false;
      }
    }
    return true;
  }

  Future<void> _writeManifest(String zipDir, DateTime createdAt) async {
    final manifest = BackupManifestJson(
      _backupVersion,
      createdAt.millisecondsSinceEpoch,
    );
    await _writeJsonToFile(manifest, p.join(zipDir, _manifestFile));
  }

  Future<void> _saveBackupFile(String filePath, DateTime date) async {
    final dateStr = DateFormat("yyyy-MM-dd-HH-mm-ss").format(date);
    final zipName = "$_zipFilePrefix-$dateStr.zip";
    final backupRoot = await backupDir;
    final zipDstPath = p.join(backupRoot, zipName);
    await File(filePath).copy(zipDstPath);
  }

  Future<void> _archiveDirToZipFile(String srcDir, String dstPath) async {
    final zipEncoder = ZipFileEncoder();
    await zipEncoder.zipDirectory(Directory(srcDir), filename: dstPath);
    await zipEncoder.close();
  }

  Future<void> _backupGeoData(
    String zipDir,
    List<BackupGeoDataJson> rows,
  ) async {
    final datDir = p.join(zipDir, _datDir);
    await FileTool.checkDir(datDir);
    final files = await GeoDataService().publishedFiles();
    for (final geoData in rows) {
      final file = files.singleWhere((file) => file.row.name == geoData.name);
      await file.data.copy(p.join(datDir, file.fileName));
      await file.indexFile.copy(p.join(datDir, '${file.row.name}.json'));
    }
    final geoDataPath = p.join(zipDir, _geoDataFile);
    await _writeJsonToFile(rows, geoDataPath);
  }

  Future<void> _writeJsonToFile(Object? data, String path) async {
    final json = switch (data) {
      BackupManifestJson() => data.toJson(),
      List<BackupCoreConfigJson>() => data.map((e) => e.toJson()).toList(),
      List<BackupSubscriptionJson>() => data.map((e) => e.toJson()).toList(),
      List<BackupGeoDataJson>() => data.map((e) => e.toJson()).toList(),
      List<BackupRoutingProfileJson>() => data.map((e) => e.toJson()).toList(),
      _ => data,
    };
    await File(path).writeAsString(JsonTool.encoder.convert(json));
  }

  Future<void> _refreshRestoredSubscriptions(
    List<SubscriptionData> subscriptions,
  ) async {
    for (final subscription in subscriptions) {
      try {
        await SubscriptionService().refreshSubscription(subscription, false);
      } catch (e, stackTrace) {
        ygLogger(
          "refresh restored subscription error (${e.runtimeType})\n$stackTrace",
        );
      }
    }
  }
}

class _BackupPayload {
  final String rootDir;
  final DateTime createdAt;
  final BackupDatabaseContents contents;

  const _BackupPayload({
    required this.rootDir,
    required this.createdAt,
    required this.contents,
  });
}
