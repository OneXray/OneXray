import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/geodata/detail.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/geo_data/model.dart';

void main() {
  for (final locale in [const Locale('en'), const Locale('fa')]) {
    testWidgets(
      'jumping to the final Geodata category builds a bounded number of rows ($locale)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const lastCode =
            'category-1499-with-a-long-name-that-must-not-wrap-in-a-narrow-layout';
        final codes = List.generate(
          1500,
          (index) => XrayGeoListCodes(
            index == 1499
                ? lastCode
                : 'category-${index.toString().padLeft(4, '0')}',
            100,
          ),
        );
        final file = _CountingGeoData(codes);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        String? copied;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: CustomScrollView(
                controller: scroll,
                slivers: [
                  GeoDataCategorySliver(
                    file: file,
                    codes: codes,
                    onCopy: (value) => copied = value,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();

        expect(file.references, lessThan(200));
        expect(find.text(lastCode), findsOneWidget);
        final l = AppLocalizations.of(
          tester.element(find.byType(GeoDataCategorySliver)),
        )!;
        await tester.tap(
          find.byTooltip('${l.prototypeCopyRuleReference}: geosite:$lastCode'),
        );
        expect(copied, 'geosite:$lastCode');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _CountingGeoData extends PublishedGeoData {
  _CountingGeoData(List<XrayGeoListCodes> codes)
    : super(
        row: GeoDataData(
          id: -2,
          name: 'geosite',
          type: 'domain',
          url: 'https://example.com/geosite.dat',
          timestamp: DateTime(2026),
          categoryCount: codes.length,
          ruleCount: codes.length * 100,
        ),
        data: File('/fixture/geosite.dat'),
        indexFile: File('/fixture/geosite.json'),
        index: XrayGeoList(codes, codes.length, codes.length * 100),
        bytes: 0,
      );

  var references = 0;

  @override
  String reference(String code) {
    references++;
    return super.reference(code);
  }
}
