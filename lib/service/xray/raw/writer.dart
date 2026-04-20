import 'dart:io';

import 'package:onexray/core/tools/file.dart';

class XrayRawWriter {
  static Future<String> writeConfig(String rawText) async {
    final configPath = await FileTool.makeCacheFile(ConfigFileType.json);
    final file = File(configPath);
    await file.writeAsString(rawText);
    return configPath;
  }
}
