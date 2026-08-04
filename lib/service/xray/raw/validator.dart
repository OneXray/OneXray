import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/raw/fix.dart';

class XrayRawValidationResult {
  final bool isValid;
  final String error;
  final String? normalizedText;
  final String? name;

  const XrayRawValidationResult._(
    this.isValid,
    this.error,
    this.normalizedText,
    this.name,
  );

  const XrayRawValidationResult.valid(String normalizedText, String name)
    : this._(true, "", normalizedText, name);

  const XrayRawValidationResult.invalid(String error)
    : this._(false, error, null, null);
}

class XrayRawValidator {
  static XrayRawValidationResult normalize(
    String rawText, {
    String? nameOverride,
  }) {
    late final Map<String, dynamic> jsonMap;
    late final XrayJson xrayJson;
    try {
      final decoded = JsonTool.decoder.convert(rawText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("Xray config root must be an object");
      }
      jsonMap = decoded;
      final normalizedNameOverride = nameOverride?.trim();
      if (normalizedNameOverride != null && normalizedNameOverride.isNotEmpty) {
        jsonMap['name'] = normalizedNameOverride;
      }
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
    return XrayRawValidationResult.valid(normalizedText, xrayJson.name!);
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

    await FileTool.checkDir(VpnConstants.runDir);
    final rawText = JsonTool.encoder.convert(jsonMap);
    return AppHostApi().testXray(rawText);
  }
}
