import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/errors/json_diagnostic.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/settings/language/service.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/shared/xray/validation.dart';

class XrayRawValidationResult {
  final bool isValid;
  final String error;
  final String? normalizedText;
  final String? name;
  final JsonDiagnostic? diagnostic;
  final Map<String, dynamic>? json;

  const XrayRawValidationResult._(
    this.isValid,
    this.error,
    this.normalizedText,
    this.name,
    this.diagnostic,
    this.json,
  );

  const XrayRawValidationResult._valid(
    String normalizedText,
    String name,
    Map<String, dynamic> json,
  ) : this._(true, "", normalizedText, name, null, json);

  const XrayRawValidationResult.invalid(
    String error, {
    JsonDiagnostic? diagnostic,
  }) : this._(false, error, null, null, diagnostic, null);
}

class XrayRawValidator {
  static XrayRawValidationResult normalize(
    String rawText, {
    String? nameOverride,
  }) {
    late final Map<String, dynamic> jsonMap;
    final normalizedNameOverride = nameOverride?.trim();
    var overrideName = false;
    try {
      final decoded = JsonTool.decoder.convert(rawText);
      if (decoded is! Map<String, dynamic>) {
        throw const JsonDiagnostic(
          "Xray config root must be an object",
          path: [],
        );
      }
      jsonMap = decoded;
      overrideName =
          normalizedNameOverride?.isNotEmpty == true &&
          jsonMap['name'] != normalizedNameOverride;
      if (overrideName) {
        jsonMap['name'] = normalizedNameOverride;
      }
    } catch (error) {
      return XrayRawValidationResult.invalid(
        failureDetails(error),
        diagnostic: JsonDiagnostic.fromError(error),
      );
    }
    final name = jsonMap['name'];
    if (name is! String || !EmptyTool.checkString(name)) {
      final message = appLocalizationsNoContext().validationNameRequired;
      return XrayRawValidationResult.invalid(
        message,
        diagnostic: JsonDiagnostic(message, path: const ['name']),
      );
    }

    // Saving is not runtime compilation. Keep the exact source, including all
    // expert fields and formatting, unless the caller explicitly renames it.
    final normalizedText = overrideName
        ? JsonTool.encoder.convert(jsonMap)
        : rawText;
    return XrayRawValidationResult._valid(normalizedText, name, jsonMap);
  }

  static Future<XrayRawValidationResult> validate(
    String rawText, {
    Future<String> Function(String)? testXray,
  }) => validateParsed(normalize(rawText), testXray: testXray);

  /// The parsed draft belongs to this operation, not a reusable validation cache.
  static Future<XrayRawValidationResult> validateParsed(
    XrayRawValidationResult normalized, {
    Future<String> Function(String)? testXray,
  }) => GeoDataService().withFiles(() async {
    if (!normalized.isValid) {
      return normalized;
    }

    final res = await (testXray ?? AppHostApi().testXray)(
      XrayValidation.raw(normalized.json!),
    );
    if (res.isNotEmpty) {
      return XrayRawValidationResult.invalid(res);
    }

    return normalized;
  });
}
