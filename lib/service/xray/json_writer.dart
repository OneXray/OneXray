import 'dart:io';

import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/constants.dart';

extension XrayJsonWriter on XrayJson {
  Future<String> test() async {
    final configPath = await FileTool.makeCacheFile(ConfigFileType.json);
    await _writeToPath(configPath);

    final res = await AppHostApi().testXray(VpnConstants.datDir, configPath);
    ygLogger(configPath);
    await FileTool.deleteFileIfExists(configPath);

    return res;
  }

  Future<int> ping(PingState pingState, String port) async {
    final configPath = await FileTool.makeCacheFile(ConfigFileType.json);
    await _writeToPath(configPath);

    final res = await AppHostApi().ping(
      VpnConstants.datDir,
      configPath,
      pingState.timeout.toInt(),
      pingState.realUrl,
      "http://${NetConstants.proxyHost}:$port",
    );
    await FileTool.deleteFileIfExists(configPath);

    return res;
  }

  Future<void> _writeToPath(String configPath) async {
    final data = JsonTool.encodeJsonToSortedString(
      toJson(),
      JsonTool.encoderForFile,
    );
    await File(configPath).writeAsString(data);
  }

  Future<String> writeConfig(String runDir) async {
    final configPath = XrayStateConstants.configFilePath;
    await _writeToPath(configPath);
    return configPath;
  }

  static Future<void> buildMphCache(
    String datDir,
    String mphCachePath,
    String configPath,
  ) async {
    await AppHostApi().buildMphCache(datDir, mphCachePath, configPath);
  }
}
