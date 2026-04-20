import 'dart:io';

import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/pigeon/constants.dart';

extension StartVpnRequestWriter on StartVpnRequest {
  Future<void> writeToStartFile() async {
    final data = JsonTool.encoderForFile.convert(toJson());
    final filePath = VpnConstants.startPath;
    await File(filePath).writeAsString(data);
  }
}
