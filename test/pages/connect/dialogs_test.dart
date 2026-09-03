import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('bottom dialog paints its safe area in $brightness', (
      tester,
    ) async {
      const size = Size(390, 844);
      const bottomInset = 34.0;
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.material(brightness, mobile: true),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: size,
              padding: EdgeInsets.only(bottom: bottomInset),
              viewPadding: EdgeInsets.only(bottom: bottomInset),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showConnectDialog<void>(
                  context,
                  (context) => ConnectDialog(
                    title: 'Traffic',
                    body: const SizedBox(height: 100),
                    actions: [
                      ConnectDialogButton(
                        label: 'Done',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final surface = find
          .descendant(
            of: find.byType(ConnectDialog),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getRect(surface).bottom, size.height);
      expect(
        tester.widget<Material>(surface).color,
        AppColorTokens.fallback(brightness).palette.card,
      );
      expect(
        tester.getRect(find.byType(FilledButton)).bottom,
        lessThanOrEqualTo(size.height - bottomInset),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(ConnectDialog), findsNothing);
    });
  }
}
