import 'package:onexray/core/errors/json_diagnostic.dart';
import 'package:onexray/core/tools/json.dart';

/// The decoded value and exact text belong to one import/edit operation.
final class ConfigurationSource {
  final String text;
  final Object? value;
  const ConfigurationSource._(this.text, this.value);

  factory ConfigurationSource.parse(String text) {
    try {
      return ConfigurationSource._(text, JsonTool.decoder.convert(text));
    } on FormatException catch (error) {
      throw JsonDiagnostic.fromError(error)!;
    }
  }

  factory ConfigurationSource.encoded(Map<String, dynamic> json) =>
      ConfigurationSource._(JsonTool.encoder.convert(json), json);
}
