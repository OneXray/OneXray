import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/l10n/localizations/app_localizations_fa.dart';
import 'package:onexray/l10n/localizations/app_localizations_ru.dart';
import 'package:onexray/l10n/localizations/app_localizations_zh.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/routing/smart/controller.dart';
import 'package:onexray/pages/routing/smart/regions.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/routing/region_catalog.dart';
import 'package:onexray/service/routing/smart_editor.dart';

void main() {
  test('Smart preview retains direct sources after merging rules', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final coordinator = ConnectionCoordinator(database: db);
    addTearDown(coordinator.dispose);
    final controller = SmartRoutingEditorController(
      service: SmartRoutingEditorService(
        database: db,
        coordinator: coordinator,
      ),
    );
    addTearDown(controller.close);
    final l = AppLocalizationsZh();
    expect(controller.directPreview(l), l.prototypeNone);
    controller.emit(
      SmartRoutingEditorState(
        original: SmartRoutingEditorDraft(
          configuration: ConnectionConfiguration(),
          regions: RegionCatalog.fromJson(
            {'geosite': <String, dynamic>{}, 'geoip': <String, dynamic>{}},
            geositeCodes: [],
            geoipCodes: [],
          ),
        ),
        busy: false,
      ),
    );
    expect(controller.rulesFor('direct'), hasLength(2));
    expect(
      controller.directPreview(l),
      [
        l.prototypeLocalNetworkPrivateAddresses,
        l.prototypeAppleServices,
      ].join(' / '),
    );
    controller.update('directPrivate', false);
    expect(controller.directPreview(l), l.prototypeAppleServices);
    controller.update('directApple', false);
    expect(controller.rulesFor('direct'), isEmpty);
    expect(controller.directPreview(l), l.prototypeNone);
  });

  test('direct regions use installed categories, support many selections and stay draft-only', () async {
    final selected = ['CN', 'IR'];
    var available = ['CN', 'RU', 'US', 'JP'];
    final controller = DirectRegionsController(
      selected,
      loadRegions: () async => RegionCatalog.fromJson(
        {
          'geosite': {
            'RU': ['CATEGORY-RU'],
          },
          'geoip': {
            for (final code in ['CN', 'RU', 'IR', 'US', 'JP']) code: [code],
          },
        },
        geositeCodes: [],
        geoipCodes: available,
      ),
    );
    addTearDown(controller.close);
    await controller.load();
    expect(controller.state.codes, ['CN', 'JP', 'RU', 'US']);
    expect(controller.state.selected, {'CN'});
    for (final code in ['RU', 'US', 'JP']) {
      controller.toggle(code);
    }
    expect(controller.state.selected.length, 4);
    controller.toggle('IR');
    expect(controller.state.selected.contains('IR'), false);
    controller.search('russia');
    expect(controller.visibleCodes(AppLocalizationsEn()), ['RU']);
    expect(controller.visibleCodes(AppLocalizationsZh()), ['RU']);
    expect(controller.detail('RU'), 'Russia · RU');
    expect(controller.detail('AD'), 'Andorra · AD');
    controller.search('us');
    expect(controller.visibleCodes(AppLocalizationsEn()), ['RU', 'US']);
    controller.clear();
    expect(controller.state.selected, isEmpty);
    expect(selected, ['CN', 'IR']);
    available = ['US'];
    await controller.load();
    expect(controller.state.codes, ['US']);
  });

  test('every bundled region has a name in every supported language', () {
    final mapping = jsonDecode(
      File(RegionCatalog.assetPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    final codes = (mapping['geoip'] as Map<String, dynamic>).keys;
    final localizations = <AppLocalizations>[
      AppLocalizationsEn(),
      AppLocalizationsFa(),
      AppLocalizationsRu(),
      AppLocalizationsZh(),
      AppLocalizationsZhHant(),
    ];

    for (final l10n in localizations) {
      for (final code in codes) {
        expect(
          setupRegionLabel(l10n, code),
          isNot(code),
          reason: '${l10n.localeName}: $code',
        );
      }
    }
    expect(setupRegionLabel(AppLocalizationsEn(), 'zz'), 'ZZ');
  });
}
