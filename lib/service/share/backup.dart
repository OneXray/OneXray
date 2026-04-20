import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/gen/assets.gen.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/share/protocol.dart';
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
// -- config.txt
// -- subscription.txt
// -- dat.txt
// -- dat
//    -- geo.dat
//    -- geo.json

class BackupService {
  static final BackupService _singleton = BackupService._internal();

  factory BackupService() => _singleton;

  BackupService._internal();

  static const _datDir = "dat";
  static const _datFile = "dat.txt";
  static const _configFile = "config.txt";
  static const _subscriptionFile = "subscription.txt";

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

    await FileTool.deleteDirIfExists(cacheDir);
    return Tuple2(true, date);
  }

  Future<void> backup() async {
    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);

    final cacheDir = await FileTool.makeCacheDir();
    final dataDir = p.join(cacheDir, _dataDir);
    await FileTool.checkDir(dataDir);

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
    final links = <String>[];
    for (final geoData in geoList) {
      final link = AppShareService().generateGeoDataLink(geoData).item1;
      links.add(link);
      await _copyDat(geoData.name, VpnConstants.datDir, datDir);
    }
    final sharePath = p.join(zipDir, _datFile);
    await _writeLinksToFile(links, sharePath);
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
    final links = <String>[];
    for (final config in configs) {
      final link = await AppShareService().generateConfigLink(config);
      links.add(link.item1);
    }
    final sharePath = p.join(zipDir, _configFile);
    await _writeLinksToFile(links, sharePath);
  }

  Future<void> _backupSubscriptions(String zipDir) async {
    final db = AppDatabase();
    final configs = await db.subscriptionDao.allRows;
    final links = configs
        .map((e) => AppShareService().generateSubscriptionLink(e).item1)
        .toList();
    final sharePath = p.join(zipDir, _subscriptionFile);
    await _writeLinksToFile(links, sharePath);
  }

  Future<void> _writeLinksToFile(List<String> links, String path) async {
    final text = links.join("\n");
    await File(path).writeAsString(text);
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
      await _clearAllData();

      await _restoreGeoData(dataDir);
      await _restoreLocalConfigs(dataDir);
      await _restoreSubscriptions(dataDir);
    }

    await FileTool.deleteDirIfExists(cacheDir);

    eventBus.updateDownloading(false);

    return true;
  }

  Future<void> _clearAllData() async {
    await PreferencesKey().saveRunningConfigId(DBConstants.defaultId);
    await PreferencesKey().saveLastConfigId(DBConstants.defaultId);
    await PreferencesKey().saveXraySettingId(DBConstants.defaultId);

    final db = AppDatabase();
    await db.geoDataDao.clear();
    await db.coreConfigDao.clear();
    await db.subscriptionDao.clear();

    final datPath = VpnConstants.datDir;
    await FileTool.deleteDirIfExists(datPath);
    await FileTool.checkDir(datPath);
    await FileTool.copyAssets(Assets.dat.values, datPath);
  }

  Future<void> _restoreGeoData(String dataDir) async {
    final datSrcDir = p.join(dataDir, _datDir);
    await FileTool.copyDir(datSrcDir, VpnConstants.datDir);

    final sharePath = p.join(dataDir, _datFile);
    final text = await File(sharePath).readAsString();
    await AppShareService().parseShareText(text, needDownload: false);
  }

  Future<void> _restoreLocalConfigs(String dataDir) async {
    final sharePath = p.join(dataDir, _configFile);
    final text = await File(sharePath).readAsString();
    final result = await AppShareService().parseShareText(text);
    await ConfigWriter.writeRows(result.item1, null);
  }

  Future<void> _restoreSubscriptions(String dataDir) async {
    final sharePath = p.join(dataDir, _subscriptionFile);
    final text = await File(sharePath).readAsString();
    await AppShareService().parseShareText(text);
  }
}
