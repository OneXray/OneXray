import 'package:onexray/core/errors/json_diagnostic.dart';
import 'package:onexray/service/advanced/xray/geodata/model.dart';

/// Import-only metadata is shared by both routing formats, never by the core.
List<Map<String, String>> routingAssets(Object? value) {
  if (value is! Map<String, dynamic> ||
      value.keys.any((key) => key != 'assets') ||
      value['assets'] is! List) {
    throw const JsonDiagnostic(
      'geodata must contain only an assets array',
      path: ['geodata'],
    );
  }
  final names = <String>{};
  return [
    for (final (index, asset) in (value['assets'] as List).indexed)
      () {
        if (asset is! Map<String, dynamic> ||
            asset.keys.any((key) => key != 'file' && key != 'url') ||
            asset['file'] is! String ||
            asset['url'] is! String) {
          throw JsonDiagnostic(
            'geodata.assets requires file and url',
            path: ['geodata', 'assets', index],
          );
        }
        final file = asset['file'] as String;
        final url = asset['url'] as String;
        try {
          GeoDataInput.referenceFileName(file);
        } on FormatException catch (error) {
          throw JsonDiagnostic(
            error.message,
            path: ['geodata', 'assets', index, 'file'],
          );
        }
        try {
          GeoDataInput.httpsUri(url);
        } on FormatException catch (error) {
          throw JsonDiagnostic(
            error.message,
            path: ['geodata', 'assets', index, 'url'],
          );
        }
        if (!names.add(file.toLowerCase())) {
          throw JsonDiagnostic(
            'Duplicate Geodata filename',
            path: ['geodata', 'assets', index, 'file'],
          );
        }
        return Map<String, String>.unmodifiable({'file': file, 'url': url});
      }(),
  ];
}
