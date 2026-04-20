import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import "package:path/path.dart" as p;
import 'package:path_provider/path_provider.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:uuid/uuid.dart';

class ConfigFileType {
  static const json = ".json";
}

class FileTool {
  static Future<void> checkDir(String path) async {
    final dir = Directory(path);
    final exists = await dir.exists();
    if (!exists) {
      await dir.create();
    }
  }

  static Future<void> deleteDirIfExists(String path) async {
    final dir = Directory(path);
    final exists = await dir.exists();
    if (exists) {
      await dir.delete(recursive: true);
    }
  }

  static Future<void> deleteFileIfExists(String path) async {
    final file = File(path);
    final exists = await file.exists();
    if (exists) {
      await file.delete();
    }
  }

  static Future<String> makeCacheDir() async {
    final cacheDir = await getApplicationCacheDirectory();
    final uuid = const Uuid().v8();
    final rootDir = p.join(cacheDir.path, uuid);
    await FileTool.checkDir(rootDir);
    return rootDir;
  }

  static Future<String> makeCacheFile(String fileType) async {
    final cacheDir = await getApplicationCacheDirectory();
    final uuid = const Uuid().v8();
    final path = p.join(cacheDir.path, "$uuid$fileType");
    return path;
  }

  static Future<void> clearTextFile(String filePath) async {
    final file = File(filePath);
    await file.writeAsString("");
  }

  static Future<void> copyDir(String srcDir, String dstDir) async {
    final files = await Directory(srcDir).list().toList();
    for (final file in files) {
      final srcPath = file.path;
      final srcFile = File(srcPath);
      final dstPath = p.join(dstDir, p.basename(srcPath));
      await srcFile.copy(dstPath);
    }
  }

  static Future<bool> saveFile(
    String path,
    String name,
    String extension,
  ) async {
    final data = await File(path).readAsBytes();
    return saveData(data, name, extension);
  }

  static Future<bool> saveData(
    Uint8List data,
    String name,
    String extension,
  ) async {
    Uint8List? bytes = data;
    if (AppPlatform.isDesktop) {
      bytes = null;
    }
    String? outputFile = await FilePicker.saveFile(
      fileName: name,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );

    if (outputFile == null) {
      return false;
    }

    if (AppPlatform.isDesktop) {
      await File(outputFile).writeAsBytes(data);
    }

    return true;
  }

  static Future<void> copyAssets(List<String> assets, String dstDir) async {
    for (final asset in assets) {
      final fileName = _readAssetFileName(asset);
      final data = await rootBundle.load(asset);
      final dstPath = p.join(dstDir, fileName);
      final bytes = Uint8List.sublistView(data);
      await File(dstPath).writeAsBytes(bytes);
    }
  }

  static String _readAssetFileName(String asset) {
    final names = asset.split("/");
    return names.last;
  }
}
