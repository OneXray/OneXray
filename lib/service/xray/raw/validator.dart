import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/raw/fix.dart';
import 'package:onexray/service/xray/raw/writer.dart';
import 'package:tuple/tuple.dart';

class XrayRawValidator {
  static Future<Tuple2<bool, String>> validate(String rawText) async {
    Map<String, dynamic> jsonMap = {};
    try {
      jsonMap = JsonTool.decoder.convert(rawText);
    } catch (_) {
      return Tuple2(false, appLocalizationsNoContext().validationJsonInvalid);
    }
    final xrayJson = XrayJson.fromJson(jsonMap);
    if (!EmptyTool.checkString(xrayJson.name)) {
      return Tuple2(false, appLocalizationsNoContext().validationNameRequired);
    }

    final res = await _test(jsonMap);
    if (res.isNotEmpty) {
      return Tuple2(false, res);
    }

    return Tuple2(true, "");
  }

  static Future<String> _test(Map<String, dynamic> jsonMap) async {
    // remove app-managed runtime inbounds
    XrayRawFix.fixInboundsTun(jsonMap);
    // remove metrics
    XrayRawFix.fixMetrics(jsonMap);

    final rawText = JsonTool.encoderForDb.convert(jsonMap);
    final configPath = await XrayRawWriter.writeConfig(rawText);
    await FileTool.checkDir(VpnConstants.runDir);
    final res = await AppHostApi().testXray(VpnConstants.datDir, configPath);
    await FileTool.deleteFileIfExists(configPath);

    return res;
  }
}
