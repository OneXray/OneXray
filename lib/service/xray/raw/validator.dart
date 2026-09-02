import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/localizations/service.dart';

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
    } catch (_) {
      return XrayRawValidationResult.invalid(
        appLocalizationsNoContext().validationJsonInvalid,
      );
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
    String? assetDirectory,
  }) async {
    final normalized = normalize(rawText);
    if (!normalized.isValid) {
      return normalized;
    }

    final jsonMap = JsonTool.decoder.convert(
      normalized.normalizedText!,
    ) as Map<String, dynamic>;
    final res = await _test(
      jsonMap,
      testXray ?? (text) => AppHostApi().testXray(text, buildOnly: true),
      assetDirectory ?? VpnConstants.datDir,
    );
    if (res.isNotEmpty) {
      return XrayRawValidationResult.invalid(res);
    }

    return normalized;
  }

  static Future<String> _test(
    Map<String, dynamic> jsonMap,
    Future<String> Function(String) testXray,
    String assetDirectory,
  ) async {
    // Build the complete configuration without constructing devices/listeners.
    // Only this disposable copy gets App-owned resource paths and logging.
    final env = jsonMap['env'];
    if (env != null && env is! Map<String, dynamic>) {
      return 'env must be an object';
    }
    jsonMap['env'] = <String, dynamic>{
      if (env is Map<String, dynamic>) ...env,
      'xray.location.asset': assetDirectory,
      'xray.location.cert': assetDirectory,
    };
    jsonMap['log'] = <String, dynamic>{
      'access': 'none',
      'error': 'none',
      'loglevel': 'none',
      'dnsLog': false,
    };
    final rawText = JsonTool.encoder.convert(jsonMap);
    return testXray(rawText);
  }
}
