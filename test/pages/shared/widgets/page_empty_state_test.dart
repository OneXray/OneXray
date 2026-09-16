import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/shared/widgets/page_empty_state.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/settings/backup/service.dart';
import 'package:onexray/service/settings/language/locale.dart';

void main() {
  for (final tab in [
    AppPrimaryDestination.connect,
    AppPrimaryDestination.servers,
  ]) {
    for (final (width, locale) in [
      (320.0, const Locale('en')),
      (390.0, const Locale('zh')),
      (390.0, const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')),
      (320.0, const Locale('ru')),
      (320.0, const Locale('fa')),
      (1160.0, const Locale('en')),
    ]) {
      testWidgets(
        'empty ${tab.name} opens backup in its own tab ($locale / $width)',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 720));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final router = GoRouter(
            initialLocation: tab.rootPath,
            routes: [
              GoRoute(
                path: tab.rootPath,
                builder: (_, _) => Scaffold(
                  body: PageEmptyState(
                    title: 'No servers',
                    description: 'Add servers or restore a backup.',
                    primaryLabel: 'Add servers',
                    onPrimary: () {},
                    secondaryLabel: 'Learn more',
                    onSecondary: () {},
                  ),
                ),
                routes: [
                  GoRoute(
                    path: AppPageDestination.backup.segment,
                    builder: (context, _) {
                      expect(context.currentPrimaryDestination, tab);
                      return Scaffold(
                        appBar: AppBar(title: const Text('Backup destination')),
                      );
                    },
                  ),
                ],
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalePolicy.localizationsDelegates,
            ),
          );
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(PageEmptyState)),
          )!;
          final restore = find.widgetWithText(
            OutlinedButton,
            l.backupRestoreFrom,
          );
          if (!BackupService.supported) {
            expect(restore, findsNothing);
            return;
          }
          await tester.ensureVisible(restore);
          await tester.tap(restore);
          await tester.pumpAndSettle();
          final destination = find.text('Backup destination');
          expect(destination, findsOneWidget);
          expect(
            GoRouterState.of(tester.element(destination)).uri.path,
            '${tab.rootPath}/backup',
          );
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.byType(PageEmptyState), findsOneWidget);
          expect(
            GoRouterState.of(tester.element(find.byType(PageEmptyState)))
                .uri
                .path,
            tab.rootPath,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
