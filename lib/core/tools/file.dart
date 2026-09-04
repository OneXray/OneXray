import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:onexray/core/tools/logger.dart';
import "package:path/path.dart" as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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

  static Future<String> makeCacheDir() async {
    final cacheDir = await getApplicationCacheDirectory();
    final uuid = const Uuid().v8();
    final rootDir = p.join(cacheDir.path, uuid);
    await FileTool.checkDir(rootDir);
    return rootDir;
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
    final outputFile = await FilePicker.saveFile(
      fileName: name,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: data,
    );

    if (outputFile == null) {
      return false;
    }
    return true;
  }

  static Future<void> copyAssets(List<String> assets, String dstDir) async {
    for (final asset in assets) {
      try {
        final fileName = _readAssetFileName(asset);
        final data = await rootBundle.load(asset);
        final dstPath = p.join(dstDir, fileName);
        final bytes = Uint8List.sublistView(data);
        await File(dstPath).writeAsBytes(bytes);
      } catch (e) {
        ygLogger("copy asset failed: $asset, $e");
      }
    }
  }

  static String _readAssetFileName(String asset) {
    final names = asset.split("/");
    return names.last;
  }
}
