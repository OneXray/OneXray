import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/routing/region_catalog.dart';
import 'package:onexray/service/geo_data/service.dart';
import 'package:path/path.dart' as p;

/// One read of actually installed category indexes, separated by condition type.
/// Load again on editor entry or an update; no bundled example is a fallback.
class RoutingGeodataIndex {
  final Map<String, List<String>> domainFiles;
  final Map<String, List<String>> ipFiles;
  const RoutingGeodataIndex({required this.domainFiles, required this.ipFiles});

  static Future<RoutingGeodataIndex> load({
    AppDatabase? database,
    String? directory,
  }) async {
    if (directory == null) {
      final files = await GeoDataService().publishedFiles();
      Map<String, List<String>> entries(String type) => {
        for (final file in files)
          if (file.row.type == type)
            file.fileName: RegionCatalog.codesFromIndex(file.index.toJson()),
      };
      return RoutingGeodataIndex(
        domainFiles: entries('domain'),
        ipFiles: entries('ip'),
      );
    }
    final db = database ?? AppDatabase();
    final root = directory;
    final files = <String, String>{'geosite.dat': 'domain', 'geoip.dat': 'ip'};
    for (final row in await db.geoDataDao.allRows) {
      final name = row.name.endsWith('.dat') ? row.name : '${row.name}.dat';
      if (p.posix.basename(name) != name || p.windows.basename(name) != name) {
        continue;
      }
      if (name == 'geosite.dat' || name == 'geoip.dat') continue;
      if (row.type == 'domain' || row.type == 'ip') files[name] = row.type;
    }
    final domains = <String, List<String>>{};
    final ips = <String, List<String>>{};
    for (final file in files.entries) {
      final dat = File(p.join(root, file.key));
      final index = File(
        p.join(root, '${p.basenameWithoutExtension(file.key)}.json'),
      );
      if (!await dat.exists() || !await index.exists()) continue;
      try {
        final codes = RegionCatalog.codesFromIndex(
          jsonDecode(await index.readAsString()) as Map<String, dynamic>,
        );
        (file.value == 'domain' ? domains : ips)[file.key] = codes;
      } on FormatException {
        // A broken index offers no fabricated categories; manual input remains.
      } on TypeError {
        // Treat malformed index fields the same as an invalid JSON document.
      } on FileSystemException {
        // Publication/removal may finish between the existence check and read.
      }
    }
    return RoutingGeodataIndex(domainFiles: domains, ipFiles: ips);
  }

  List<String> suggestions(String query, {required bool domain}) =>
      RegionCatalog.suggestions(
        query,
        domain: domain,
        files: domain ? domainFiles : ipFiles,
      );

  Future<RegionCatalog> regionCatalog() async => RegionCatalog.fromJson(
    jsonDecode(await rootBundle.loadString(RegionCatalog.assetPath))
        as Map<String, dynamic>,
    geositeCodes: domainFiles['geosite.dat'] ?? const [],
    geoipCodes: ipFiles['geoip.dat'] ?? const [],
  );
}
