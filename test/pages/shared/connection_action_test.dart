import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/connection_action.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/resolver.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  for (final (error, message) in [
    (
      const ConnectionResolutionException(
        ConnectionResolutionFailure.selectionUnavailable,
      ),
      'No available entry servers · Add servers',
    ),
    (
      const ConnectionResolutionException(
        ConnectionResolutionFailure.insufficientHealthyServers,
        requiredCount: 3,
        availableCount: 1,
      ),
      'Not enough available servers (1/3)',
    ),
    (
      const ConnectionResolutionException(
        ConnectionResolutionFailure.cancelled,
      ),
      null,
    ),
  ]) {
    testWidgets('connection action feedback: ${error.reason.name}', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final coordinator = ConnectionCoordinator(database: db);
      addTearDown(db.close);
      addTearDown(coordinator.dispose);
      bool? succeeded;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalePolicy.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => ShadTheme(
            data: AppTheme.shad(Brightness.light),
            child: ShadToaster(child: child!),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: ShadButton(
                child: const Text('Connect'),
                onPressed: () async {
                  succeeded = await runConnectionAction(
                    context,
                    coordinator,
                    () async => throw error,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(succeeded, isFalse);
      if (message != null) {
        expect(find.text(message), findsOneWidget);
      } else {
        expect(find.byType(ShadToast), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
