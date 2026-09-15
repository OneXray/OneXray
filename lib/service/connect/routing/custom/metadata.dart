import 'package:onexray/service/advanced/xray/geodata/model.dart';

/// Import-only metadata is shared by both routing formats, never by the core.
List<Map<String, String>> routingAssets(Object? value) {
  if (value is! Map<String, dynamic> ||
      value.keys.any((key) => key != 'assets') ||
      value['assets'] is! List) {
    throw const FormatException('geodata must contain only an assets array');
  }
  final names = <String>{};
  return [
    for (final asset in value['assets'] as List)
      () {
        if (asset is! Map<String, dynamic> ||
            asset.keys.any((key) => key != 'file' && key != 'url') ||
            asset['file'] is! String ||
            asset['url'] is! String) {
          throw const FormatException('geodata.assets requires file and url');
        }
        final file = asset['file'] as String;
        final url = asset['url'] as String;
        GeoDataInput.referenceFileName(file);
        GeoDataInput.httpsUri(url);
        if (!names.add(file.toLowerCase())) {
          throw const FormatException('Duplicate Geodata filename');
        }
        return Map<String, String>.unmodifiable({'file': file, 'url': url});
      }(),
  ];
}
