import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/pages/routing/smart/regions.dart';
import 'package:onexray/service/routing/region_catalog.dart';

void main() {
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
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.codes, ['CN', 'JP', 'RU', 'US']);
    expect(controller.selected, {'CN'});
    for (final code in ['RU', 'US', 'JP']) {
      controller.toggle(code);
    }
    expect(controller.selected.length, 4);
    controller.toggle('IR');
    expect(controller.selected.contains('IR'), false);
    controller.search('russia');
    expect(controller.visibleCodes(AppLocalizationsEn()), ['RU']);
    controller.search('us');
    expect(controller.visibleCodes(AppLocalizationsEn()), ['RU', 'US']);
    controller.clear();
    expect(controller.selected, isEmpty);
    expect(selected, ['CN', 'IR']);
    available = ['US'];
    await controller.load();
    expect(controller.codes, ['US']);
  });
}
