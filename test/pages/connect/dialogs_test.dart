import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/theme.dart';

void main() {
  testWidgets('destructive confirmation keeps subject and warning structure', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDestructiveConfirmationDialog(
                  context,
                  title: 'Delete this server?',
                  subtitle: 'Tokyo 01',
                  warning: 'This change cannot be undone.',
                  confirmLabel: 'Delete',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this server?'), findsOneWidget);
    expect(find.text('Tokyo 01'), findsOneWidget);
    expect(find.text('This change cannot be undone.'), findsOneWidget);
    expect(
      tester.widget<ConnectCallout>(find.byType(ConnectCallout)).warning,
      isTrue,
    );
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('reconnect confirmation names the pending configuration', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showApplyAndReconnectDialog(
                  context,
                  label: 'Daily route',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Apply this change?'), findsOneWidget);
    expect(find.text('Will use: Daily route'), findsOneWidget);

    await tester.tap(find.text('Apply and reconnect'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

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
