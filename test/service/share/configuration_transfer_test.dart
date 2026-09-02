import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/routing/custom_service.dart';
import 'package:onexray/service/share/app_link_generator.dart';
import 'package:onexray/service/share/app_link_model.dart';
import 'package:onexray/service/share/app_link_parser.dart';
import 'package:onexray/service/share/configuration_transfer.dart';

String template(String name, {bool assets = false}) => jsonEncode({
  'name': name,
  'outbounds': [{}, {}],
  'routing': {
    'rules': [
      {
        'ruleTag': 'Local websites',
        'domain': [assets ? 'ext:rules.dat:cn' : 'domain:example.com'],
        'balancerTag': 'proxy',
      },
    ],
  },
  if (assets)
    'geodata': {
      'assets': [
        {'file': 'rules.dat', 'url': 'https://example.com/rules.dat'},
      ],
    },
});

void main() {
  test('custom transfer consumes only its manifest and preserves native rule fields', () {
    final content = ConfigurationTransferService.read(
      template('Route', assets: true),
      ConfigurationKind.custom,
    );
    final json = jsonDecode(content.text) as Map<String, dynamic>;
    expect(json, isNot(contains('geodata')));
    expect(content.name, 'Route');
    expect(content.assets.single.fileName, 'rules.dat');
    expect(content.assets.single.type, GeoDataType.domain);
    expect((json['outbounds'] as List), [{}, {}]);
    expect(
      (json['routing']['rules'] as List).single['ruleTag'],
      'Local websites',
    );
    expect(
      () => ConfigurationTransferService.read(
        template(
          'Route',
        ).replaceFirst('"balancerTag"', '"source":["1.1.1.1"],"balancerTag"'),
        ConfigurationKind.custom,
      ),
      throwsFormatException,
    );
  });

  test('Raw source and independent source links round trip without formatting or double encoding', () async {
    const source =
        '  { "outbounds": [], "dns": {"servers":[{"domains":["ext:rules.dat:cn"]}]}, "future": 123 }\n';
    final service = ConfigurationTransferService(
      lookup: (name) async => GeoDataData(
        id: 1,
        name: name,
        type: 'domain',
        url: 'https://example.com/rules.dat',
        timestamp: DateTime(2026),
        categoryCount: 1,
        ruleCount: 1,
      ),
      prepare: (_) async => throw StateError('Export must not download'),
    );
    expect(
      await service.exportJson(
        kind: ConfigurationKind.raw,
        name: 'Metadata',
        text: source,
      ),
      source,
    );
    final text = await service.shareLinks(
      kind: ConfigurationKind.raw,
      name: 'Metadata',
      text: source,
    );
    final links = OneXrayAppLinkParser.parseText(text);
    expect(links, hasLength(2));
    expect(links.first, isA<OneXrayGeoDataLink>());
    expect((links.last as OneXrayConfigLink).xrayJson, source);
    final read = ConfigurationTransferService.read(text, ConfigurationKind.raw);
    expect(read.text, source);
    expect(read.name, 'Metadata');
    expect(read.assets.single.fileName, 'rules.dat');
  });

  test(
    'Custom share uses type=custom with assets but never selected servers',
    () async {
      final service = ConfigurationTransferService(
        lookup: (_) async => null,
        prepare: (_) async => throw StateError('No dependencies'),
      );
      final text = await service.shareLinks(
        kind: ConfigurationKind.custom,
        name: 'Shared',
        text: template('Draft'),
      );
      final link =
          OneXrayAppLinkParser.parse(Uri.parse(text))! as OneXrayConfigLink;
      expect(link.type, OneXrayConfigLinkType.custom);
      expect(link.name, 'Shared');
      expect(jsonDecode(link.xrayJson)['name'], 'Shared');
      expect(jsonDecode(link.xrayJson)['outbounds'], [{}, {}]);
    },
  );

  test('reference collection ignores arbitrary strings and rejects mixed file types and unsafe manifests', () {
    expect(geoDataReferences({'password': 'ext:secret.dat:cn'}), isEmpty);
    expect(
      () => geoDataReferences({
        'routing': {
          'rules': [
            {
              'domain': ['ext:same.dat:cn'],
              'ip': ['ext:same.dat:cn'],
            },
          ],
        },
      }),
      throwsFormatException,
    );
    for (final file in ['../rules.dat', 'rules.DAT', 'geosite.dat']) {
      expect(
        () => ConfigurationTransferService.read(
          template('Route', assets: true).replaceAll('rules.dat', file),
          ConfigurationKind.custom,
        ),
        throwsFormatException,
      );
    }
  });

  test('editor dependency preparation never publishes; caller commits and disposes explicitly', () async {
    var writes = 0;
    var disposed = 0;
    final service = ConfigurationTransferService(
      lookup: (_) async => null,
      prepare: (inputs) async => GeoDataImportDraft(
        inputs,
        () async {
          writes++;
        },
        () async {
          disposed++;
        },
        (_) async {},
      ),
    );
    final draft = await service.import(
      template('Route', assets: true),
      ConfigurationKind.custom,
    );
    expect(writes, 0);
    final exported = jsonDecode(
      await service.exportJson(
        kind: ConfigurationKind.custom,
        name: draft.name,
        text: draft.text,
        pending: draft.geodata,
      ),
    );
    expect(exported['geodata']['assets'].single['file'], 'rules.dat');
    await draft.commit();
    await draft.dispose();
    expect(writes, 1);
    expect(disposed, 1);
  });

  test('common import previews Custom rather than nodes; batch limits roll back dependencies and configs', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final service = ServerImportService(
      database: db,
      parse: (_) async => throw StateError('Custom must not reach node parser'),
      validate: (_) async => '',
      schedule: (_) => throw StateError('Routes are not nodes'),
      transfer: ConfigurationTransferService(
        lookup: db.geoDataDao.searchRowByName,
        prepare: (inputs) async => GeoDataImportDraft(
          inputs,
          () async {
            await db.geoDataDao.insertRow(
              GeoDataCompanion.insert(
                name: 'rules',
                type: 'domain',
                url: inputs.single.url,
                timestamp: DateTime(2026),
                categoryCount: 1,
                ruleCount: 1,
              ),
            );
          },
          () async {},
          (_) async {},
        ),
      ),
    );
    final first = await service.preview(template('One'));
    expect(first.count, 0);
    expect(first.rawCount, 0);
    expect(first.customRoutes.single.name, 'One');
    expect(await db.customRoutingProfilesDao.allRows, isEmpty);
    final result = await service.commit(first);
    expect(result.customCount, 1);
    await CustomRoutingService(db).save(name: 'Two', text: template('Two'));
    await CustomRoutingService(db).save(name: 'Three', text: template('Three'));
    final next = await service.preview(template('Fourth', assets: true));
    expect(await db.geoDataDao.allRows, isEmpty);
    await expectLater(service.commit(next), throwsA(isA<StateError>()));
    expect(await db.geoDataDao.allRows, isEmpty);
    expect(await db.customRoutingProfilesDao.allRows, hasLength(3));
    await next.dispose();
  });

  test('type=custom rejects unsupported rules without falling back to Raw or node import', () async {
    final invalid = template('Route')
        .replaceFirst('"ruleTag"', '"inboundTag":["secret"],"ruleTag"');
    final link = OneXrayAppLinkGenerator.configurationText(
      OneXrayConfigLinkType.custom,
      'Route',
      invalid,
    );
    final service = ServerImportService(
      parse: (_) async => throw StateError('Unexpected fallback'),
    );
    final preview = await service.preview(link.toString());
    expect(preview.hasItems, false);
    expect(preview.failureCount, 1);
  });
}
