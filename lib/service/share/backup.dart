import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/data_cleanup/service.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
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
// -- dat
//    -- geo.dat
//    -- geo.json

class BackupService {
  static final BackupService _singleton = BackupService._internal();

  factory BackupService() => _singleton;

  BackupService._internal();

  static const _backupVersion = 3;
  static const _datDir = "dat";
  static const _manifestFile = "manifest.json";
  static const _coreConfigsFile = "core_configs.json";
  static const _subscriptionsFile = "subscriptions.json";
  static const _geoDataFile = "geo_data.json";

  static const _zipFilePrefix = "OneXray";

  // backup zip files dir, in application support directory
  static const _backupName = "backup";

  Future<String> get backupDir async {
    final rootPath = await getApplicationSupportDirectory();
    final backupPath = p.join(rootPath.path, _backupName);
    await FileTool.checkDir(backupPath);
    return backupPath;
  }

  Future<bool> importBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["zip"],
    );
    if (result == null) {
      return false;
    }
    final file = result.files.single;
    if (file.path == null) {
      return false;
    }

    final cacheDir = await FileTool.makeCacheDir();
    try {
      final payload = await _readBackupPayload(file.path!, cacheDir);
      if (payload == null) {
        return false;
      }
      await _saveBackupFile(file.path!, payload.createdAt);
      return true;
    } finally {
      await FileTool.deleteDirIfExists(cacheDir);
    }
  }

  Future<void> backup() async {
    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);

    final cacheDir = await FileTool.makeCacheDir();
    final stagingDir = p.join(cacheDir, "staging");
    final createdAt = DateTime.now();
    try {
      await FileTool.checkDir(stagingDir);
      await _writeManifest(stagingDir, createdAt);
      await _backupGeoData(stagingDir);
      await _backupLocalConfigs(stagingDir);
      await _backupSubscriptions(stagingDir);

      final zipSrcPath = p.join(cacheDir, "$_zipFilePrefix.zip");
      await _archiveDirToZipFile(stagingDir, zipSrcPath);
      await _saveBackupFile(zipSrcPath, createdAt);
    } catch (e, stackTrace) {
      ygLogger("backup error: $e\n$stackTrace");
      rethrow;
    } finally {
      await FileTool.deleteDirIfExists(cacheDir);
      eventBus.updateDownloading(false);
    }
  }

  Future<bool> restore(String zipPath) async {
    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);

    final cacheDir = await FileTool.makeCacheDir();
    try {
      final payload = await _readBackupPayload(zipPath, cacheDir);
      if (payload == null) {
        return false;
      }

      final cleared = await AppDataCleanupService().clearForBackupRestore();
      if (!cleared) {
        return false;
      }

      await _restoreGeoData(payload);
      await _restoreLocalConfigs(payload);
      await _restoreSubscriptions(payload);
      return true;
    } catch (e, stackTrace) {
      ygLogger("restore backup error: $e\n$stackTrace");
      return false;
    } finally {
      await FileTool.deleteDirIfExists(cacheDir);
      eventBus.updateDownloading(false);
    }
  }

  Future<_BackupPayload?> _readBackupPayload(
    String zipPath,
    String cacheDir,
  ) async {
    try {
      await extractFileToDisk(zipPath, cacheDir);
      return _readBackupDir(cacheDir);
    } catch (e, stackTrace) {
      ygLogger("read backup error: $e\n$stackTrace");
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
    if (coreConfigs == null || subscriptions == null || geoDataList == null) {
      return null;
    }

    if (!_validateCoreConfigs(coreConfigs) ||
        !_validateSubscriptions(subscriptions) ||
        !await _validateGeoDataList(backupRoot, geoDataList)) {
      return null;
    }

    return _BackupPayload(
      rootDir: backupRoot,
      createdAt: DateTime.fromMillisecondsSinceEpoch(manifest.createdAt!),
      coreConfigs: coreConfigs,
      subscriptions: subscriptions,
      geoDataList: geoDataList,
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
        manifest.version != _backupVersion ||
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

  bool _validateCoreConfigs(List<BackupCoreConfigJson> configs) {
    for (final config in configs) {
      if (config.name == null || config.type == null || config.tags == null) {
        return false;
      }
    }
    return true;
  }

  bool _validateSubscriptions(List<BackupSubscriptionJson> subscriptions) {
    for (final subscription in subscriptions) {
      if (subscription.name == null ||
          subscription.url == null ||
          subscription.timestamp == null ||
          subscription.expanded == null) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _validateGeoDataList(
    String backupRoot,
    List<BackupGeoDataJson> geoDataList,
  ) async {
    final datDir = p.join(backupRoot, _datDir);
    for (final geoData in geoDataList) {
      final name = geoData.name;
      if (name == null ||
          geoData.type == null ||
          geoData.url == null ||
          geoData.timestamp == null ||
          geoData.categoryCount == null ||
          geoData.ruleCount == null) {
        return false;
      }

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
    final dateStr = DateFormat("yyyy-MM-dd").format(date);
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

  Future<void> _backupGeoData(String zipDir) async {
    final datDir = p.join(zipDir, _datDir);
    await FileTool.checkDir(datDir);
    final db = AppDatabase();
    final geoList = await db.geoDataDao.allRows;
    final rows = <BackupGeoDataJson>[];
    for (final geoData in geoList) {
      rows.add(
        BackupGeoDataJson(
          geoData.name,
          geoData.type,
          geoData.url,
          geoData.timestamp.millisecondsSinceEpoch,
          geoData.categoryCount,
          geoData.ruleCount,
        ),
      );
      await _copyDat(geoData.name, VpnConstants.datDir, datDir);
    }
    final geoDataPath = p.join(zipDir, _geoDataFile);
    await _writeJsonToFile(rows, geoDataPath);
  }

  Future<void> _copyDat(String name, String srcDir, String dstDir) async {
    final datName = "$name.dat";
    final datSrcPath = p.join(srcDir, datName);
    final datDstPath = p.join(dstDir, datName);
    await File(datSrcPath).copy(datDstPath);

    final jsonName = "$name.json";
    final jsonSrcPath = p.join(srcDir, jsonName);
    final jsonDstPath = p.join(dstDir, jsonName);
    await File(jsonSrcPath).copy(jsonDstPath);
  }

  Future<void> _backupLocalConfigs(String zipDir) async {
    final db = AppDatabase();
    final configs = await db.coreConfigDao.allLocalRowsWithData;
    final rows = configs
        .map(
          (config) => BackupCoreConfigJson(
            config.name,
            config.type,
            config.tags,
            config.data,
          ),
        )
        .toList();
    final configsPath = p.join(zipDir, _coreConfigsFile);
    await _writeJsonToFile(rows, configsPath);
  }

  Future<void> _backupSubscriptions(String zipDir) async {
    final db = AppDatabase();
    final subscriptions = await db.subscriptionDao.allRows;
    final rows = subscriptions
        .map(
          (subscription) => BackupSubscriptionJson(
            subscription.name,
            subscription.url,
            subscription.timestamp.millisecondsSinceEpoch,
            subscription.expanded,
          ),
        )
        .toList();
    final subscriptionsPath = p.join(zipDir, _subscriptionsFile);
    await _writeJsonToFile(rows, subscriptionsPath);
  }

  Future<void> _writeJsonToFile(Object? data, String path) async {
    final json = switch (data) {
      BackupManifestJson() => data.toJson(),
      List<BackupCoreConfigJson>() => data.map((e) => e.toJson()).toList(),
      List<BackupSubscriptionJson>() => data.map((e) => e.toJson()).toList(),
      List<BackupGeoDataJson>() => data.map((e) => e.toJson()).toList(),
      _ => data,
    };
    await File(path).writeAsString(JsonTool.encoderForFile.convert(json));
  }

  Future<void> _restoreGeoData(_BackupPayload payload) async {
    final datSrcDir = p.join(payload.rootDir, _datDir);
    if (await Directory(datSrcDir).exists()) {
      await FileTool.copyDir(datSrcDir, VpnConstants.datDir);
    }

    final db = AppDatabase();
    for (final geoData in payload.geoDataList) {
      await db.geoDataDao.insertRow(
        GeoDataCompanion.insert(
          name: geoData.name!,
          type: geoData.type!,
          url: geoData.url!,
          timestamp: _readTimestamp(geoData.timestamp),
          categoryCount: geoData.categoryCount!,
          ruleCount: geoData.ruleCount!,
        ),
      );
    }
  }

  Future<void> _restoreLocalConfigs(_BackupPayload payload) async {
    final configs = <CoreConfigCompanion>[];
    for (final config in payload.coreConfigs) {
      configs.add(
        CoreConfigCompanion.insert(
          name: config.name!,
          type: config.type!,
          tags: config.tags!,
          data: Value<String?>(config.data),
          delay: PingDelayConstants.unknown,
          subId: DBConstants.defaultId,
        ),
      );
    }
    await ConfigWriter.writeRows(configs, null);
  }

  Future<void> _restoreSubscriptions(_BackupPayload payload) async {
    final db = AppDatabase();
    for (final row in payload.subscriptions) {
      final timestamp = _readTimestamp(row.timestamp);
      final subId = await db.subscriptionDao.insertRow(
        SubscriptionCompanion.insert(
          name: row.name!,
          url: row.url!,
          timestamp: timestamp,
          count: 0,
          expanded: row.expanded!,
        ),
      );
      if (subId > DBConstants.defaultId) {
        final subscription = SubscriptionData(
          id: subId,
          name: row.name!,
          url: row.url!,
          timestamp: timestamp,
          count: 0,
          expanded: row.expanded!,
        );
        await SubscriptionService().refreshSubscription(subscription, false);
      }
    }
  }

  DateTime _readTimestamp(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }
}

class _BackupPayload {
  final String rootDir;
  final DateTime createdAt;
  final List<BackupCoreConfigJson> coreConfigs;
  final List<BackupSubscriptionJson> subscriptions;
  final List<BackupGeoDataJson> geoDataList;

  const _BackupPayload({
    required this.rootDir,
    required this.createdAt,
    required this.coreConfigs,
    required this.subscriptions,
    required this.geoDataList,
  });
}
