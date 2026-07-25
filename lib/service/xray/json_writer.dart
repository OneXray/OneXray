import 'dart:io';

import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/constants.dart';

extension XrayJsonWriter on XrayJson {
  Future<String> test() async {
    final configPath = await FileTool.makeCacheFile(ConfigFileType.json);
    await _writeToPath(configPath);
    await FileTool.checkDir(VpnConstants.runDir);

    final res = await AppHostApi().testXray(configPath);
    ygLogger(configPath);
    await FileTool.deleteFileIfExists(configPath);

    return res;
  }

  Future<void> _writeToPath(String configPath) async {
    _fixRuntimeEnv();
    final jsonMap = toJson();
    final data = JsonTool.encodeJsonToSortedString(jsonMap);
    await File(configPath).writeAsString(data);
  }

  void _fixRuntimeEnv() {
    env = XrayEnv(
      assetLocation: VpnConstants.datDir,
      certLocation: VpnConstants.datDir,
    );
  }

  Future<String> writeConfig(String runDir) async {
    final configPath = XrayStateConstants.configFilePath;
    await _writeToPath(configPath);
    return configPath;
  }
}
