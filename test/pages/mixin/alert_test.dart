import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('showOKDialog uses a Shad dialog', (tester) async {
    await tester.pumpWidget(
      _AlertTestApp(
        onPressed: (context) =>
            ContextAlert.showOKDialog(context, 'Ping Result', '42 ms'),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(find.byType(ShadDialog), findsOneWidget);
    expect(find.text('Ping Result'), findsOneWidget);
    expect(find.text('42 ms'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(ShadDialog), findsNothing);
  });

  testWidgets('showToast uses the shared Shad toaster', (tester) async {
    await tester.pumpWidget(
      _AlertTestApp(
        onPressed: (context) async {
          ContextAlert.showToast(context, 'Saved');
        },
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.byType(ShadToast), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}

class _AlertTestApp extends StatelessWidget {
  const _AlertTestApp({required this.onPressed});

  final Future<void> Function(BuildContext context) onPressed;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => ShadTheme(
        data: AppTheme.shad(Brightness.light),
        child: ShadToaster(child: child ?? const SizedBox.shrink()),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ShadButton(
              onPressed: () => onPressed(context),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
  }
}
