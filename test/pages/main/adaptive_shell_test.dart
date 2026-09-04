import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/adaptive_shell.dart';
import 'package:onexray/pages/main/dialog_page.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/service.dart';

void main() {
  test('primary destinations use product names and URLs', () {
    expect(AppPrimaryDestination.values.map((route) => route.name), [
      'connect',
      'servers',
      'advanced',
      'settings',
    ]);
    expect(AppPrimaryDestination.values.map((route) => route.rootPath), [
      '/connect',
      '/servers',
      '/advanced',
      '/settings',
    ]);
    expect(
      AppPrimaryDestination.fromPath('/advanced/routing-data'),
      AppPrimaryDestination.advanced,
    );
  });

  testWidgets('shared navigation breakpoints preserve the update flow', (
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

    final rootKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: AppPrimaryDestination.connect.rootPath,
      routes: [
        GoRoute(
          path: AppDialogRoutePath.appUpdate,
          builder: (_, _) => const Center(child: Text('update-dialog')),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, navigationShell) =>
              AdaptiveMainShell(navigationShell: navigationShell),
          branches: [
            for (final primary in AppPrimaryDestination.values)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: primary.rootPath,
                    builder: (_, _) =>
                        Center(child: Text('${primary.name}-content')),
                    routes: [
                      GoRoute(
                        path: 'details',
                        builder: (_, _) => const Center(child: Text('details')),
                      ),
                      GoRoute(
                        path: 'popup',
                        parentNavigatorKey: rootKey,
                        pageBuilder: (context, state) => AppDialogPage<void>(
                          key: state.pageKey,
                          useSafeArea: false,
                          builder: (context) => AppDialogFrame(
                            child: AppDialog(
                              title: 'root-popup',
                              body: const SizedBox(height: 100),
                              actions: [
                                FilledButton(
                                  onPressed: () => context.pop(),
                                  child: const Text('close-popup'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

    final desktopNavigation = find.byKey(
      const ValueKey('primary-desktop-navigation'),
    );
    expect(find.text('connect-content'), findsOneWidget);
    expect(find.text('OneXray'), findsOneWidget);
    expect(
      tester.getSize(desktopNavigation).width,
      AppLayout.desktopSidebarWidth,
    );
    final desktopConnect = find.byKey(
      const ValueKey('primary-navigation-connect'),
    );
    expect(
      tester.widget<Semantics>(desktopConnect).properties.selected,
      isTrue,
    );
    expect(tester.getSize(desktopConnect).height, AppSpacing.sidebarRowHeight);
    expect(
      tester.getSize(desktopConnect).width,
      AppLayout.desktopSidebarWidth - AppSpacing.sidebarHorizontal * 2 - 1,
    );
    for (final width in [900.0, 721.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(desktopNavigation).width,
        AppLayout.compactSidebarWidth,
      );
      expect(find.text('OneXray'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(const Size(720, 800));
    await tester.pumpAndSettle();
    expect(desktopNavigation, findsNothing);
    final navigation = find.byKey(const ValueKey('primary-mobile-navigation'));
    final connectDestination = find.byKey(
      const ValueKey('primary-navigation-connect'),
    );
    expect(navigation, findsOneWidget);
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.height, isNull);
    expect(navigationBar.selectedIndex, AppPrimaryDestination.connect.index);
    expect(
      navigationBar.destinations,
      hasLength(AppPrimaryDestination.values.length),
    );
    expect(
      tester.widget<NavigationDestination>(connectDestination).label,
      'Connect',
    );
    expect(find.byType(Badge), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppPrimaryDestination.settings.index,
    );
    for (final path in ['/settings', '/settings/details']) {
      router.go(path);
      await tester.pumpAndSettle();
      final root = path == '/settings';
      final content = root ? 'settings-content' : 'details';
      expect(navigation, root ? findsOneWidget : findsNothing);
      expect(find.text(content), findsOneWidget);

      final closed = router.push<void>('/settings/popup');
      await tester.pumpAndSettle();
      expect(find.text('root-popup'), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(AppDialog))),
        same(rootKey.currentState),
      );
      expect(navigation, root ? findsOneWidget : findsNothing);
      expect(find.text(content), findsOneWidget);
      await tester.tap(find.text('close-popup'));
      await tester.pumpAndSettle();
      await closed;

      expect(find.byType(AppDialog), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(navigation, root ? findsOneWidget : findsNothing);
      expect(find.text(content), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    // A declarative popup location has the root, not the previous detail, below it.
    router.go('/settings/popup');
    await tester.pumpAndSettle();
    expect(find.text('root-popup'), findsOneWidget);
    expect(find.text('settings-content'), findsOneWidget);
    expect(navigation, findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.text('settings-content'), findsOneWidget);
    expect(navigation, findsOneWidget);
    expect(tester.takeException(), isNull);

    router.go('/settings/details');
    await tester.pumpAndSettle();
    expect(navigation, findsNothing);
    expect(find.text('details'), findsOneWidget);
    router.go('/connect');
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(901, 800));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(desktopNavigation).width,
      AppLayout.desktopSidebarWidth,
    );
    await tester.tap(find.text('Update available'));
    await tester.pumpAndSettle();

    expect(find.text('update-dialog'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/settings');
  });
}
