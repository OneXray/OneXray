import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/data_cleanup/service.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';

// 文件结构
// OneXray-date.zip
// -- timestamp.txt
// -- sha256sum.txt
// -- data.zip

// data
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

  static const _backupVersion = 2;
  static const _datDir = "dat";
  static const _manifestFile = "manifest.json";
  static const _coreConfigsFile = "core_configs.json";
  static const _subscriptionsFile = "subscriptions.json";
  static const _geoDataFile = "geo_data.json";

  static const _dataDir = "data";
  static const _dataFile = "data.zip";
  static const _sha256SumFile = "sha256sum.txt";
  static const _timestampFile = "timestamp.txt";

  static const _zipFilePrefix = "OneXray";

  // backup zip files dir, in application support directory
  static const _backupName = "backup";

  //=========================
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
    final filePath = file.path!;
    final check = await _testBackupFile(filePath);
    if (!check.item1) {
      return false;
    }
    await _saveBackupFile(filePath, check.item2);
    return true;
  }

  Future<Tuple2<bool, DateTime>> _testBackupFile(String filePath) async {
    final cacheDir = await FileTool.makeCacheDir();
    try {
      extractFileToDisk(filePath, cacheDir);
    } catch (_) {
      await FileTool.deleteDirIfExists(cacheDir);
      return Tuple2(false, DateTime.now());
    }

    final timestampFile = File(p.join(cacheDir, _timestampFile));
    var exist = await timestampFile.exists();
    if (!exist) {
      await FileTool.deleteDirIfExists(cacheDir);
      return Tuple2(false, DateTime.now());
    }
    var timestampStr = await timestampFile.readAsString();
    timestampStr = timestampStr.trim();
    final timestamp = int.tryParse(timestampStr);
    if (timestamp == null) {
      await FileTool.deleteDirIfExists(cacheDir);
      return Tuple2(false, DateTime.now());
    }
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    final dataZipFile = File(p.join(cacheDir, _dataFile));
    exist = await dataZipFile.exists();
    if (!exist) {
      await FileTool.deleteDirIfExists(cacheDir);
      return Tuple2(false, DateTime.now());
    }

    final sha256SumFile = File(p.join(cacheDir, _sha256SumFile));
    exist = await sha256SumFile.exists();
    if (!exist) {
      await FileTool.deleteDirIfExists(cacheDir);
      return Tuple2(false, DateTime.now());
    }
    var savedSha256Sum = await sha256SumFile.readAsString();
    savedSha256Sum = savedSha256Sum.trim();

    final dataBytes = await dataZipFile.readAsBytes();
    final sha256Sum = sha256.convert(dataBytes).toString();
    if (sha256Sum != savedSha256Sum) {
      await FileTool.deleteDirIfExists(cacheDir);
      return Tuple2(false, DateTime.now());
    }

    final validData = await _dataZipHasV2Manifest(dataZipFile.path);
    if (!validData) {
      await FileTool.deleteDirIfExists(cacheDir);
      return Tuple2(false, DateTime.now());
    }

    await FileTool.deleteDirIfExists(cacheDir);
    return Tuple2(true, date);
  }

  Future<bool> _dataZipHasV2Manifest(String dataZipPath) async {
    final cacheDir = await FileTool.makeCacheDir();
    try {
      extractFileToDisk(dataZipPath, cacheDir);
      final manifestFile = File(p.join(cacheDir, _manifestFile));
      if (!await manifestFile.exists()) {
        return false;
      }
      final manifest = jsonDecode(await manifestFile.readAsString());
      return manifest is Map && manifest["version"] == _backupVersion;
    } catch (e) {
      ygLogger("test backup manifest error: $e");
      return false;
    } finally {
      await FileTool.deleteDirIfExists(cacheDir);
    }
  }

  Future<void> backup() async {
    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);

    final cacheDir = await FileTool.makeCacheDir();
    final dataDir = p.join(cacheDir, _dataDir);
    await FileTool.checkDir(dataDir);

    await _writeManifest(dataDir);
    await _backupGeoData(dataDir);
    await _backupLocalConfigs(dataDir);
    await _backupSubscriptions(dataDir);

    final zipDir = p.join(cacheDir, _zipFilePrefix);
    await FileTool.checkDir(zipDir);

    final dataZipPath = p.join(zipDir, _dataFile);
    await _archiveDirToZipFile(dataDir, dataZipPath);

    final dataBytes = await File(dataZipPath).readAsBytes();
    final sha256Sum = sha256.convert(dataBytes).toString();
    final sha256SumPath = p.join(zipDir, _sha256SumFile);
    await File(sha256SumPath).writeAsString(sha256Sum);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await File(p.join(zipDir, _timestampFile)).writeAsString("$timestamp");

    final zipName = "$_zipFilePrefix.zip";
    final zipSrcPath = p.join(cacheDir, zipName);
    await _archiveDirToZipFile(zipDir, zipSrcPath);

    await _saveBackupFile(zipSrcPath, DateTime.now());

    ygLogger(cacheDir);
    //await FileTool.deleteDirIfExists(cacheDir);

    eventBus.updateDownloading(false);
  }

  Future<void> _writeManifest(String zipDir) async {
    final manifest = <String, dynamic>{
      "version": _backupVersion,
      "createdAt": DateTime.now().millisecondsSinceEpoch,
    };
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
    final rows = <Map<String, dynamic>>[];
    for (final geoData in geoList) {
      rows.add({
        "name": geoData.name,
        "type": geoData.type,
        "url": geoData.url,
        "timestamp": geoData.timestamp.millisecondsSinceEpoch,
        "categoryCount": geoData.categoryCount,
        "ruleCount": geoData.ruleCount,
      });
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
          (config) => <String, dynamic>{
            "name": config.name,
            "type": config.type,
            "tags": config.tags,
            "data": config.data,
          },
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
          (subscription) => <String, dynamic>{
            "name": subscription.name,
            "url": subscription.url,
            "timestamp": subscription.timestamp.millisecondsSinceEpoch,
            "expanded": subscription.expanded,
          },
        )
        .toList();
    final subscriptionsPath = p.join(zipDir, _subscriptionsFile);
    await _writeJsonToFile(rows, subscriptionsPath);
  }

  Future<void> _writeJsonToFile(Object? data, String path) async {
    await File(path).writeAsString(JsonTool.encoderForFile.convert(data));
  }

  //=========================
  Future<bool> restore(String zipPath) async {
    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);

    var res = true;
    final cacheDir = await FileTool.makeCacheDir();
    try {
      await extractFileToDisk(zipPath, cacheDir);
    } catch (e) {
      ygLogger("$e");
      res = false;
    }

    final dataZipPath = p.join(cacheDir, _dataFile);
    if (res) {
      final exist = await File(dataZipPath).exists();
      if (!exist) {
        res = false;
      }
    }

    final dataDir = p.join(cacheDir, _dataDir);
    await FileTool.checkDir(dataDir);

    if (res) {
      try {
        await extractFileToDisk(dataZipPath, dataDir);
      } catch (e) {
        ygLogger("$e");
        res = false;
      }
    }

    if (res) {
      try {
        final validData = await _dataDirHasV2Manifest(dataDir);
        if (!validData) {
          res = false;
        } else {
          final cleared = await AppDataCleanupService().clearForBackupRestore();
          if (!cleared) {
            res = false;
          } else {
            await _restoreGeoData(dataDir);
            await _restoreLocalConfigs(dataDir);
            await _restoreSubscriptions(dataDir);
          }
        }
      } catch (e) {
        ygLogger("restore backup error: $e");
        res = false;
      }
    }

    await FileTool.deleteDirIfExists(cacheDir);

    eventBus.updateDownloading(false);

    return res;
  }

  Future<bool> _dataDirHasV2Manifest(String dataDir) async {
    final manifestFile = File(p.join(dataDir, _manifestFile));
    if (!await manifestFile.exists()) {
      return false;
    }
    final manifest = jsonDecode(await manifestFile.readAsString());
    return manifest is Map && manifest["version"] == _backupVersion;
  }

  Future<void> _restoreGeoData(String dataDir) async {
    final datSrcDir = p.join(dataDir, _datDir);
    await FileTool.copyDir(datSrcDir, VpnConstants.datDir);

    final rows = await _readJsonList(p.join(dataDir, _geoDataFile));
    final db = AppDatabase();
    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }
      final name = row["name"];
      final type = row["type"];
      final url = row["url"];
      if (name is! String || type is! String || url is! String) {
        continue;
      }
      final timestamp = _readTimestamp(row["timestamp"]);
      final categoryCount = _readInt(row["categoryCount"]);
      final ruleCount = _readInt(row["ruleCount"]);
      await db.geoDataDao.insertRow(
        GeoDataCompanion.insert(
          name: name,
          type: type,
          url: url,
          timestamp: timestamp,
          categoryCount: categoryCount,
          ruleCount: ruleCount,
        ),
      );
    }
  }

  Future<void> _restoreLocalConfigs(String dataDir) async {
    final rows = await _readJsonList(p.join(dataDir, _coreConfigsFile));
    final configs = <CoreConfigCompanion>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }
      final name = row["name"];
      final type = row["type"];
      final tags = row["tags"];
      if (name is! String || type is! String || tags is! String) {
        continue;
      }
      final data = row["data"];
      configs.add(
        CoreConfigCompanion.insert(
          name: name,
          type: type,
          tags: tags,
          data: Value<String?>(data is String ? data : null),
          delay: PingDelayConstants.unknown,
          subId: DBConstants.defaultId,
        ),
      );
    }
    await ConfigWriter.writeRows(configs, null);
  }

  Future<void> _restoreSubscriptions(String dataDir) async {
    final rows = await _readJsonList(p.join(dataDir, _subscriptionsFile));
    final db = AppDatabase();
    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        continue;
      }
      final name = row["name"];
      final url = row["url"];
      if (name is! String || url is! String) {
        continue;
      }
      final timestamp = _readTimestamp(row["timestamp"]);
      final expanded = row["expanded"] == true;
      final subId = await db.subscriptionDao.insertRow(
        SubscriptionCompanion.insert(
          name: name,
          url: url,
          timestamp: timestamp,
          count: 0,
          expanded: expanded,
        ),
      );
      if (subId > DBConstants.defaultId) {
        final subscription = SubscriptionData(
          id: subId,
          name: name,
          url: url,
          timestamp: timestamp,
          count: 0,
          expanded: expanded,
        );
        await SubscriptionService().refreshSubscription(subscription, false);
      }
    }
  }

  Future<List<dynamic>> _readJsonList(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return [];
    }
    final data = jsonDecode(await file.readAsString());
    if (data is List) {
      return data;
    }
    return [];
  }

  DateTime _readTimestamp(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return 0;
  }
}
