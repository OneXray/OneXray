import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/service/xray/raw/fix.dart';
import 'package:onexray/service/xray/raw/writer.dart';

class XrayRawValidationResult {
  final bool isValid;
  final String error;
  final String? normalizedText;

  const XrayRawValidationResult._(
    this.isValid,
    this.error,
    this.normalizedText,
  );

  const XrayRawValidationResult.valid(String normalizedText)
    : this._(true, "", normalizedText);

  const XrayRawValidationResult.invalid(String error)
    : this._(false, error, null);
}

class XrayRawValidator {
  static XrayRawValidationResult normalize(String rawText) {
    late final Map<String, dynamic> jsonMap;
    late final XrayJson xrayJson;
    try {
      final decoded = JsonTool.decoder.convert(rawText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("Xray config root must be an object");
      }
      jsonMap = decoded;
      xrayJson = XrayJson.fromJson(jsonMap);
    } catch (_) {
      return XrayRawValidationResult.invalid(
        appLocalizationsNoContext().validationJsonInvalid,
      );
    }
    if (!EmptyTool.checkString(xrayJson.name)) {
      return XrayRawValidationResult.invalid(
        appLocalizationsNoContext().validationNameRequired,
      );
    }

    XrayRawFix.keepOnlyPingInbound(jsonMap);
    final normalizedText = JsonTool.encoder.convert(jsonMap);
    return XrayRawValidationResult.valid(normalizedText);
  }

  static Future<XrayRawValidationResult> validate(String rawText) async {
    final normalized = normalize(rawText);
    if (!normalized.isValid) {
      return normalized;
    }

    final jsonMap =
        JsonTool.decoder.convert(normalized.normalizedText!)
            as Map<String, dynamic>;
    final res = await _test(jsonMap);
    if (res.isNotEmpty) {
      return XrayRawValidationResult.invalid(res);
    }

    return normalized;
  }

  static Future<String> _test(Map<String, dynamic> jsonMap) async {
    XrayRawFix.fixEnv(jsonMap);
    XrayRawFix.fixMetrics(jsonMap);

    final rawText = JsonTool.encoder.convert(jsonMap);
    final configPath = await XrayRawWriter.writeConfig(rawText);
    try {
      await FileTool.checkDir(VpnConstants.runDir);
      return await AppHostApi().testXray(configPath);
    } finally {
      await FileTool.deleteFileIfExists(configPath);
    }
  }
}
