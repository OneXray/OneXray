import 'package:onexray/core/errors/failure.dart';
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
    final normalizedNameOverride = nameOverride?.trim();
    final overrideName = normalizedNameOverride?.isNotEmpty == true;
    try {
      final decoded = JsonTool.decoder.convert(rawText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("Xray config root must be an object");
      }
      jsonMap = decoded;
      if (overrideName) {
        jsonMap['name'] = normalizedNameOverride;
      }
    } catch (error) {
      return XrayRawValidationResult.invalid(failureDetails(error));
    }
    final name = jsonMap['name'];
    if (name is! String || !EmptyTool.checkString(name)) {
      return XrayRawValidationResult.invalid(
        appLocalizationsNoContext().validationNameRequired,
      );
    }

    // Saving is not runtime compilation. Keep the exact source, including all
    // expert fields and formatting, unless the caller explicitly renames it.
    final normalizedText = overrideName
        ? JsonTool.encoder.convert(jsonMap)
        : rawText;
    return XrayRawValidationResult.valid(normalizedText, name);
  }

  static Future<XrayRawValidationResult> validate(
    String rawText, {
    Future<String> Function(String)? testXray,
  }) => GeoDataService().withFiles(() async {
    final normalized = normalize(rawText);
    if (!normalized.isValid) {
      return normalized;
    }

    final jsonMap = JsonTool.decoder.convert(
      normalized.normalizedText!,
    ) as Map<String, dynamic>;
    final res = await (testXray ?? AppHostApi().testXray)(
      XrayValidation.raw(jsonMap),
    );
    if (res.isNotEmpty) {
      return XrayRawValidationResult.invalid(res);
    }

    return normalized;
  });
}
