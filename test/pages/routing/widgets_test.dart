import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/theme.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('fa')]) {
    testWidgets('entry count remains draft-only with scaled text ($locale)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var selected = 1;
      final changes = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.6)),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: RoutingCard(
                      child: RoutingEntryCountRow(
                        value: selected,
                        onChanged: (value) => setState(() {
                          selected = value;
                          changes.add(value);
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(changes, [3]);
      expect(selected, 3);
      final context = tester.element(find.byType(EntryCountPicker));
      expect(
        tester.widget<Text>(find.text('3')).style?.color,
        ColorManager.palette(context).primary,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('routing navigation hides only mobile description', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [390.0, 1100.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: RoutingCard(
              child: RoutingSettingRow(
                icon: LucideIcons.earth,
                title: 'Direct regions',
                description: 'Region explanation',
                value: 'China',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('China'), findsOneWidget);
      expect(
        find.text('Region explanation'),
        width < 720 ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
