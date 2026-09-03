import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/geodata/view.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/geo_data/model.dart';

void main() {
  for (final locale in const [
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ru'),
    Locale('fa'),
  ]) {
    testWidgets(
      'mobile Geodata rows render dates and route actions ($locale)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final builtIn = _file(-1, 'geoip', 12 * 1024 * 1024);
        final custom = _file(42, 'custom-domain', 3 * 1024 * 1024);
        final actions = <(String, PublishedGeoData)>[];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final file in [builtIn, custom])
                      GeoDataRows(
                        key: ValueKey(file.row.id),
                        files: [file],
                        custom: !file.builtIn,
                        busy: false,
                        onOpen: (value) => actions.add(('open', value)),
                        onUpdate: (value) => actions.add(('update', value)),
                        onDelete: (value) => actions.add(('delete', value)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final l = AppLocalizations.of(
          tester.element(find.byType(GeoDataRows).first),
        )!;
        for (final (file, size) in [
          (builtIn, '12.0 MiB'),
          (custom, '3.0 MiB'),
        ]) {
          final group = find.byKey(ValueKey(file.row.id));
          for (final text in [
            file.fileName,
            file.sourceHost,
            size,
            DateFormat.yMd(locale.toString())
                .add_Hm()
                .format(file.row.timestamp.toLocal()),
          ]) {
            expect(
              find.descendant(of: group, matching: find.text(text)),
              findsOneWidget,
            );
          }
          expect(
            find.descendant(of: group, matching: find.text(l.prototypeUpdate)),
            file.builtIn ? findsNothing : findsOneWidget,
          );
          expect(
            find.descendant(
              of: group,
              matching: find.byTooltip(l.prototypeDeleteCustomDataset),
            ),
            file.builtIn ? findsNothing : findsOneWidget,
          );
          await tester.tap(find.text(file.fileName));
        }
        await tester.tap(find.text(l.prototypeUpdate));
        await tester.tap(find.byTooltip(l.prototypeDeleteCustomDataset));
        expect(actions, [
          ('open', builtIn),
          ('open', custom),
          ('update', custom),
          ('delete', custom),
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

PublishedGeoData _file(int id, String name, int bytes) => PublishedGeoData(
  row: GeoDataData(
    id: id,
    name: name,
    type: id == -1 ? 'ip' : 'domain',
    url: 'https://$name.example/$name.dat',
    timestamp: DateTime(2026, 9, 3, 9, 42),
    categoryCount: 1,
    ruleCount: 100,
  ),
  data: File('/fixture/$name.dat'),
  indexFile: File('/fixture/$name.json'),
  index: XrayGeoList([XrayGeoListCodes('cn', 100)], 1, 100),
  bytes: bytes,
);
