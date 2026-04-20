import 'dart:io';

import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/pigeon/constants.dart';

extension StartVpnRequestReader on StartVpnRequest {
  static Future<StartVpnRequest> readFromStartFile() async {
    final filePath = VpnConstants.startPath;
    final data = await File(filePath).readAsString();
    final requestMap = JsonTool.decoder.convert(data);
    final request = StartVpnRequest.fromJson(requestMap);
    return request;
  }
}
