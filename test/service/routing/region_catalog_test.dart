import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/routing/region_catalog.dart';

void main() {
  test('uses current installed categories, not assumed region names', () {
    final catalog = RegionCatalog.fromJson(
      {
        'geosite': {
          'CN': ['CN'],
          'RU': ['CATEGORY-RU'],
        },
        'geoip': {
          'CN': ['CN'],
          'RU': ['RU'],
          'JP': ['JP'],
        },
      },
      geositeCodes: ['CN', 'CATEGORY-PT'],
      geoipCodes: ['cn', 'RU'],
    );
    expect(catalog.regionCodes, ['CN', 'RU']);
    expect(catalog.domainRules(['cn', 'RU', 'CN', 'JP']), ['geosite:CN']);
    expect(catalog.ipRules(['CN', 'ru', 'CN']), ['geoip:cn', 'geoip:RU']);
  });

  test(
    'autocomplete uses default, custom and attribute categories per type',
    () {
      final codes = RegionCatalog.codesFromIndex({
        'codes': [
          {'code': 'CN', 'ruleCount': 20},
          {'code': 'GOOGLE@cn', 'ruleCount': 2},
          {'code': 'EMPTY', 'ruleCount': 0},
        ],
      });
      expect(
        RegionCatalog.suggestions(
          'cn',
          domain: true,
          files: {
            'geosite.dat': codes,
            'other.dat': ['CN'],
          },
        ),
        ['ext:other.dat:CN', 'geosite:CN', 'geosite:GOOGLE@cn'],
      );
      expect(
        RegionCatalog.suggestions(
          'cn',
          domain: false,
          files: {
            'geoip.dat': ['CN'],
            'network.dat': ['CN'],
          },
        ),
        ['ext:network.dat:CN', 'geoip:CN'],
      );
      expect(RegionCatalog.codesFromIndex({}), isEmpty);
      expect(RegionCatalog.suggestions('cn', domain: true, files: {}), isEmpty);
      expect(
        RegionCatalog.suggestions(
          'cn',
          domain: true,
          files: {
            'geosite.dat': ['ACER@cn', 'CN', 'CN-EXTRA'],
            'other.dat': ['CN'],
          },
        ),
        [
          'ext:other.dat:CN',
          'geosite:CN',
          'geosite:CN-EXTRA',
          'geosite:ACER@cn',
        ],
      );
    },
  );

  test('bundled mapping excludes misleading categories and filters later removals', () {
    // The Go generator verifies real protobuf/index equality. CI uses empty dat
    // placeholders, so this pure test only reads the committed mapping asset.
    final mapping = jsonDecode(
      File(RegionCatalog.assetPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    final domainCodes = [
      'CN',
      'CATEGORY-IR',
      'CATEGORY-RU',
      'CATEGORY-TM',
      'CATEGORY-PT',
      'HM',
    ];
    final ipCodes = (mapping['geoip'] as Map<String, dynamic>).keys.toList();
    final catalog = RegionCatalog.fromJson(
      mapping,
      geositeCodes: domainCodes,
      geoipCodes: ipCodes,
    );
    expect(catalog.regionCodes.length, greaterThan(200));
    expect(catalog.domainRules(['CN', 'IR', 'RU', 'TM', 'PT', 'HM']), [
      'geosite:CN',
      'geosite:CATEGORY-IR',
      'geosite:CATEGORY-RU',
      'geosite:CATEGORY-TM',
    ]);
    expect(catalog.ipRules(['PT', 'HM']), ['geoip:PT', 'geoip:HM']);
    expect(catalog.ipRules(['ZZ', 'PRIVATE', 'TEST']), isEmpty);
    for (final rule in catalog.domainRules(catalog.regionCodes)) {
      expect(domainCodes, contains(rule.substring('geosite:'.length)));
    }
    for (final rule in catalog.ipRules(catalog.regionCodes)) {
      expect(ipCodes, contains(rule.substring('geoip:'.length)));
    }
    final updated = RegionCatalog.fromJson(
      mapping,
      geositeCodes: [],
      geoipCodes: ['RU'],
    );
    expect(updated.regionCodes, ['RU']);
    expect(updated.domainRules(['CN', 'RU']), isEmpty);
    expect(updated.ipRules(['CN', 'RU']), ['geoip:RU']);
  });
}
