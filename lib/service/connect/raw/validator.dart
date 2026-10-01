import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/errors/json_diagnostic.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/settings/language/service.dart';
import 'package:onexray/service/advanced/xray/geodata/service.dart';
import 'package:onexray/service/shared/xray/validation.dart';

final class ParsedRawConfiguration {
  final String text;
  final String name;
  final Map<String, dynamic> json;

  const ParsedRawConfiguration(this.text, this.name, this.json);
}

class XrayRawValidator {
  static ParsedRawConfiguration normalize(
    String rawText, {
    String? nameOverride,
  }) {
    late final Object? decoded;
    final normalizedNameOverride = nameOverride?.trim();
    try {
      decoded = JsonTool.decoder.convert(rawText);
    } on FormatException catch (error) {
      throw JsonDiagnostic.fromError(error)!;
    }
    if (decoded is! Map<String, dynamic>) {
      throw const JsonDiagnostic(
        "Xray config root must be an object",
        path: [],
      );
    }
    final jsonMap = decoded;
    final overrideName =
        normalizedNameOverride?.isNotEmpty == true &&
        jsonMap['name'] != normalizedNameOverride;
    if (overrideName) jsonMap['name'] = normalizedNameOverride;
    final name = jsonMap['name'];
    if (name is! String || !EmptyTool.checkString(name)) {
      throw JsonDiagnostic(
        appLocalizationsNoContext().validationNameRequired,
        path: const ['name'],
      );
    }

    // Saving is not runtime compilation. Keep the exact source, including all
    // expert fields and formatting, unless the caller explicitly renames it.
    final text = overrideName ? JsonTool.encoder.convert(jsonMap) : rawText;
    return ParsedRawConfiguration(text, name, jsonMap);
  }

  static Future<ParsedRawConfiguration> validate(
    String rawText, {
    Future<String> Function(String)? testXray,
  }) async => validateParsed(normalize(rawText), testXray: testXray);

  /// The parsed draft belongs to this operation, not a reusable validation cache.
  static Future<ParsedRawConfiguration> validateParsed(
    ParsedRawConfiguration parsed, {
    Future<String> Function(String)? testXray,
  }) => GeoDataService().withFiles(() async {
    final res = await (testXray ?? AppHostApi().testXray)(
      XrayValidation.raw(parsed.json),
    );
    if (res.isNotEmpty) {
      throw AppFailure(
        FailureCategory.configuration,
        'xrayValidation',
        cause: res,
      );
    }

    return parsed;
  });
}
