import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/routing/checker.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/routing/state.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('rule check is folded and keeps custom conditions in $locale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(427, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.material(Brightness.light, mobile: true),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RouteChecker(
              configuration: ConnectionConfiguration(),
              customDraft: RoutingProfileState(name: ''),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(RouteChecker)))!;
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text(l.prototypeCheckRules));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('github.com'), findsOneWidget);
      expect(find.text(l.prototypeTargetPort), findsOneWidget);
      expect(find.text(l.prototypeNetworkType), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text(l.prototypeCheckRules));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
