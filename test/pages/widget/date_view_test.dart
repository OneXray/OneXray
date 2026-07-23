import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/widget/date_view.dart';

void main() {
  testWidgets('date label and localized timestamp use two fixed lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: DateView(date: DateTime(2026, 7, 22, 14, 34, 44)),
          ),
        ),
      ),
    );

    expect(find.text('Last Update Time:'), findsOneWidget);
    expect(find.text('7/22/2026 14:34:44'), findsOneWidget);

    final timestamp = tester.widget<Text>(find.text('7/22/2026 14:34:44'));
    expect(timestamp.maxLines, 1);
    expect(timestamp.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timestamp follows the current locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DateView(date: DateTime(2026, 7, 22, 14, 34, 44))),
      ),
    );

    expect(find.text('上次更新时间:'), findsOneWidget);
    expect(find.text('2026/7/22 14:34:44'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
