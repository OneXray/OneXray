import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/adaptive_shell.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/service.dart';

void main() {
  testWidgets('desktop update reminder opens dialog from Settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final eventBus = AppEventBus();
    addTearDown(eventBus.close);
    eventBus.updateAppUpdateInfo(
      AppUpdateInfo(
        currentVersion: '26.7.3',
        latestVersion: '26.8.0',
        releaseNotes: 'Release notes',
        releaseUri: Uri.parse('https://example.com/release'),
        updateUri: Uri.parse('https://example.com/update'),
        destination: AppUpdateDestination.githubRelease,
      ),
    );

    final router = GoRouter(
      initialLocation: AppPrimaryRoute.home.rootPath,
      routes: [
        GoRoute(
          path: AppDialogRoutePath.appUpdate,
          builder: (_, _) => const Center(child: Text('update-dialog')),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, navigationShell) =>
              AdaptiveMainShell(navigationShell: navigationShell),
          branches: [
            for (final primary in AppPrimaryRoute.values)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: primary.rootPath,
                    builder: (_, _) =>
                        Center(child: Text('${primary.name}-content')),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      BlocProvider.value(
        value: eventBus,
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('home-content'), findsOneWidget);
    await tester.tap(find.text('Update available'));
    await tester.pumpAndSettle();

    expect(find.text('update-dialog'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/settings');
  });
}
