import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/adaptive_shell.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/service.dart';

void main() {
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
                    routes: [
                      GoRoute(
                        path: 'details',
                        builder: (_, _) => const Center(child: Text('details')),
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

    expect(find.text('home-content'), findsOneWidget);
    expect(
      tester.getSize(find.byType(NavigationRail)).width,
      AppLayout.desktopSidebarWidth,
    );
    for (final width in [900.0, 721.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(NavigationRail)).width,
        AppLayout.compactSidebarWidth,
      );
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(const Size(720, 800));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    final navigation = find.byKey(const ValueKey('primary-mobile-navigation'));
    final homeDestination = find.byKey(
      const ValueKey('primary-navigation-home'),
    );
    expect(navigation, findsOneWidget);
    expect(tester.getSize(navigation).height, AppLayout.mobileNavigationHeight);
    expect(
      tester.widget<Semantics>(homeDestination).properties.selected,
      isTrue,
    );
    expect(tester.widget<Semantics>(homeDestination).properties.button, isTrue);
    expect(find.byType(Badge), findsOneWidget);
    final homeIcon = find.descendant(
      of: homeDestination,
      matching: find.byType(Icon),
    );
    expect(tester.getSize(homeIcon).height, AppLayout.mobileNavigationIconSize);
    expect(
      tester.getTopLeft(find.text('Connect')).dy -
          tester.getBottomLeft(homeIcon).dy,
      closeTo(AppSpacing.mobileNavigationGap, 0.001),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const ValueKey('primary-navigation-settings')),
          )
          .properties
          .selected,
      isTrue,
    );
    router.go('/settings/details');
    await tester.pumpAndSettle();
    expect(navigation, findsNothing);
    expect(find.text('details'), findsOneWidget);
    router.go('/home');
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(901, 800));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(NavigationRail)).width,
      AppLayout.desktopSidebarWidth,
    );
    await tester.tap(find.text('Update available'));
    await tester.pumpAndSettle();

    expect(find.text('update-dialog'), findsOneWidget);
    // Switching roots retains the branch's existing subpage.
    expect(router.routeInformationProvider.value.uri.path, '/settings/details');
  });
}
