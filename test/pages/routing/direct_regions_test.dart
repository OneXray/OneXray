import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/l10n/localizations/app_localizations_zh.dart';
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
    expect(controller.detail('AD'), 'AD');
    controller.search('us');
    expect(controller.visibleCodes(AppLocalizationsEn()), ['RU', 'US']);
    controller.clear();
    expect(controller.state.selected, isEmpty);
    expect(selected, ['CN', 'IR']);
    available = ['US'];
    await controller.load();
    expect(controller.state.codes, ['US']);
  });
}
