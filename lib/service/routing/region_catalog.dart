/// Uses one installed generation's category indexes. Recreate after publication;
/// the bundled mapping alone is never proof that a category is still installed.
final class RegionCatalog {
  static const assetPath = 'assets/geodata/regions.json';

  final Map<String, List<String>> _domains;
  final Map<String, List<String>> _ips;

  RegionCatalog.fromJson(
    Map<String, dynamic> mapping, {
    required Iterable<String> geositeCodes,
    required Iterable<String> geoipCodes,
  }) : _domains = _available(mapping['geosite'], geositeCodes),
       _ips = _available(mapping['geoip'], geoipCodes);

  List<String> get regionCodes =>
      ({..._domains.keys, ..._ips.keys}.toList()..sort());

  List<String> domainRules(Iterable<String> codes) =>
      _rules(codes, _domains, 'geosite');

  List<String> ipRules(Iterable<String> codes) => _rules(codes, _ips, 'geoip');

  static Map<String, List<String>> _available(
    Object? mapping,
    Iterable<String> installed,
  ) {
    final actual = {for (final code in installed) code.toUpperCase(): code};
    final result = <String, List<String>>{};
    for (final entry in (mapping as Map<String, dynamic>).entries) {
      final categories = <String>{};
      for (final code in entry.value as List<dynamic>) {
        final match = actual[(code as String).toUpperCase()];
        if (match != null) categories.add(match);
      }
      if (categories.isNotEmpty) {
        result[entry.key.toUpperCase()] = categories.toList();
      }
    }
    return result;
  }

  static List<String> _rules(
    Iterable<String> codes,
    Map<String, List<String>> mapping,
    String prefix,
  ) => {
    for (final code in codes)
      for (final category in mapping[code.toUpperCase()] ?? const <String>[])
        '$prefix:$category',
  }.toList();

  /// Accepts the current countGeoData JSON, including attribute categories.
  /// An absent/empty index offers no categories, never a bundled fallback.
  static List<String> codesFromIndex(Map<String, dynamic> index) => [
    for (final entry in index['codes'] as List<dynamic>? ?? const [])
      if (entry['code'] is String &&
          (entry['code'] as String).isNotEmpty &&
          (entry['ruleCount'] as num? ?? 0) > 0)
        entry['code'] as String,
  ];

  /// [files] uses saved .dat basenames from one generation, separated by type
  /// by the caller. Pass fresh indexes after a successful Geodata publication.
  static List<String> suggestions(
    String query, {
    required bool domain,
    required Map<String, Iterable<String>> files,
  }) {
    final defaultFile = domain ? 'geosite.dat' : 'geoip.dat';
    final prefix = domain ? 'geosite' : 'geoip';
    final search = query.trim().toLowerCase();
    return {
      for (final file in files.entries)
        for (final code in file.value)
          if ((file.key == defaultFile
                  ? '$prefix:$code'
                  : 'ext:${file.key}:$code')
              .toLowerCase()
              .contains(search))
            file.key == defaultFile ? '$prefix:$code' : 'ext:${file.key}:$code',
    }.toList()..sort();
  }
}
