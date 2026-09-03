import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/model/geo_dat.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/geodata/view.dart';
import 'package:onexray/pages/advanced/geodata/controller.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:onexray/service/geo_data/service.dart';

void main() {
  testWidgets(
    'Geodata updates guard only the same file and release on failure',
    (tester) async {
      final service = _PendingGeoDataService();
      final controller = GeoDataController(service: service);
      addTearDown(controller.dispose);
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final first = _file(42, 'first', 100);
      final second = _file(43, 'second', 100);
      controller.files = [first, second];
      final firstUpdate = controller.update(context, first);
      await controller.update(context, first);
      final secondUpdate = controller.update(context, second);
      await controller.updateAll(context);
      expect(service.calls, [42, 43]);
      expect(controller.fileBusy(42), isTrue);
      expect(controller.fileBusy(43), isTrue);
      expect(controller.fileBusy(-1), isFalse);
      expect(controller.formBusy, isFalse);
      expect(controller.canUpdateAll, isFalse);
      service.pending[42]!.complete();
      await firstUpdate;
      expect(controller.fileBusy(42), isFalse);
      expect(controller.fileBusy(43), isTrue);
      service.pending[43]!.completeError(StateError('download failed'));
      await secondUpdate;
      expect(controller.errors[43], isNotNull);
      expect(controller.fileBusy(43), isFalse);
      expect(controller.canUpdateAll, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'busy Geodata row keeps other files and detail navigation enabled',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final actions = <int>[];
      final first = _file(42, 'first-long-custom-dataset-name', 100);
      final second = _file(43, 'second', 100);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: GeoDataRows(
              files: [first, second],
              custom: true,
              busy: false,
              updating: const {42},
              onOpen: (file) => actions.add(file.row.id),
              onUpdate: (file) => actions.add(file.row.id),
              onDelete: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      final l = AppLocalizations.of(tester.element(find.byType(GeoDataRows)))!;
      final buttons = tester
          .widgetList<TextButton>(
            find.widgetWithText(TextButton, l.prototypeUpdate),
          )
          .toList();
      expect(buttons.first.onPressed, isNull);
      expect(buttons.last.onPressed, isNotNull);
      expect(find.byType(ButtonProgressIndicator), findsOneWidget);
      await tester.tap(find.text(first.fileName));
      await tester.tap(find.text(l.prototypeUpdate).last);
      expect(actions, [42, 43]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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

class _PendingGeoDataService implements GeoDataService {
  final calls = <int>[];
  final pending = <int, Completer<void>>{};

  @override
  Future<void> updateCustom(GeoDataData original, {bool downloading = true}) {
    calls.add(original.id);
    return (pending[original.id] = Completer<void>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
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
