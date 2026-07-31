import 'dart:io';

import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/constants.dart';

extension XrayJsonWriter on XrayJson {
  Future<String> test() async {
    await FileTool.checkDir(VpnConstants.runDir);
    return AppHostApi().testXray(_encode());
  }

  Future<void> _writeToPath(String configPath) async {
    final data = _encode();
    await File(configPath).writeAsString(data);
  }

  String _encode() {
    _fixRuntimeEnv();
    final jsonMap = toJson();
    return JsonTool.encodeJsonToSortedString(jsonMap);
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
