import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/pages/main/page_visibility.dart';
import 'package:onexray/service/connection/coordinator.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets(
      'traffic demand follows retained tabs, pages and dialog ($width)',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final coordinator = _Coordinator();
        final controller = ConnectController(
          database: coordinator.db,
          coordinator: coordinator,
        );
        late StatefulNavigationShell shell;
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (_, _, navigationShell) {
                shell = navigationShell;
                return navigationShell;
              },
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/home',
                      builder: (context, _) => PageVisibility(
                        onChanged: controller.setPageVisible,
                        child: Scaffold(
                          body: TextButton(
                            onPressed: () => controller.showTraffic(context),
                            child: const Text('open-traffic'),
                          ),
                        ),
                      ),
                      routes: [
                        GoRoute(
                          path: 'edit',
                          builder: (_, _) =>
                              const Scaffold(body: Text('editor')),
                        ),
                      ],
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/servers',
                      builder: (_, _) => const Scaffold(body: Text('servers')),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        );
        await tester.pumpAndSettle();
        expect(coordinator.visible, isTrue);

        shell.goBranch(1);
        await tester.pumpAndSettle();
        expect(coordinator.visible, isFalse);
        shell.goBranch(0);
        await tester.pumpAndSettle();
        expect(coordinator.visible, isTrue);

        router.push('/home/edit');
        await tester.pumpAndSettle();
        expect(coordinator.visible, isFalse);
        router.pop();
        await tester.pumpAndSettle();
        expect(coordinator.visible, isTrue);

        await tester.tap(find.text('open-traffic'));
        await tester.pumpAndSettle();
        expect(coordinator.visible, isTrue);
        // The traffic surface retains demand even when its owner is covered.
        controller.setPageVisible(false);
        expect(coordinator.visible, isTrue);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(coordinator.visible, isFalse);
        controller.setPageVisible(true);
        await tester.pumpWidget(const SizedBox());
        expect(coordinator.visible, isFalse);
        expect(tester.takeException(), isNull);
        controller.dispose();
        coordinator.dispose();
        router.dispose();
        await coordinator.db.close();
      },
    );
  }
}

class _Coordinator extends ConnectionCoordinator {
  _Coordinator()
    : super(database: AppDatabase.forTesting(NativeDatabase.memory()));
  bool visible = false;

  @override
  void setTrafficVisible(bool visible) => this.visible = visible;
}
