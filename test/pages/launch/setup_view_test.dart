import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/page.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/launch/setup/widgets.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.material(Brightness.light, mobile: true),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => ShadTheme(
    data: AppTheme.shad(Brightness.light, mobile: true),
    child: child!,
  ),
  home: child,
);

void _mobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final locale in const [Locale('zh'), Locale('ru'), Locale('fa')]) {
    testWidgets('welcome points remain centered and wrap for $locale', (
      tester,
    ) async {
      _mobile(tester);
      await tester.pumpWidget(
        _app(
          SetupView(
            state: const SetupPageState(busy: false),
            requiresInterface: false,
            supportsScan: true,
            onAction: (_) {},
            onAddServer: (_) {},
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      for (final element in find.byType(SetupPoint).evaluate()) {
        final bounds = tester.getRect(
          find.byElementPredicate((item) => item == element),
        );
        expect(bounds.left, greaterThanOrEqualTo(24));
        expect(bounds.right, lessThanOrEqualTo(366));
        expect(bounds.center.dx, closeTo(195, .1));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'welcome and privacy use production views without setup services',
    (tester) async {
      _mobile(tester);
      final actions = <SetupAction>[];
      await tester.pumpWidget(
        _app(
          SetupView(
            state: const SetupPageState(busy: false),
            requiresInterface: false,
            supportsScan: true,
            onAction: actions.add,
            onAddServer: (_) => fail('No import requested on welcome'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Welcome to OneXray'), findsOneWidget);
      expect(find.textContaining('You provide your own servers'), findsNothing);
      await tester.tap(find.text('Privacy policy'));
      await tester.tap(find.text('Agree and continue'));
      expect(actions, [SetupAction.privacy, SetupAction.acceptPrivacy]);
      expect(tester.takeException(), isNull);

      var policies = 0;
      var backs = 0;
      await tester.pumpWidget(
        _app(
          SetupPrivacyView(
            onBack: () => backs++,
            onOpenPolicy: () => policies++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('You provide your own servers'),
        findsOneWidget,
      );
      await tester.tap(find.text('Read the full privacy policy'));
      await tester.tap(find.text('Back'));
      expect(policies, 1);
      expect(backs, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system states gate Continue but never request permission in build',
    (tester) async {
      _mobile(tester);
      final actions = <SetupAction>[];
      final waiting = SetupPageState(
        step: SetupStep.system,
        busy: false,
        localReady: true,
        permission: PlatformPermissionResult(
          kind: PlatformPermissionKind.androidVpn,
          state: PlatformPermissionState.notDetermined,
        ),
      );
      Future<void> show(SetupPageState state, {bool interface = false}) async {
        await tester.pumpWidget(
          _app(
            SetupView(
              state: state,
              requiresInterface: interface,
              supportsScan: true,
              failureText: state.failure == null
                  ? null
                  : 'VPN permission is required. Please retry to continue.',
              onAction: actions.add,
              onAddServer: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await show(waiting);
      expect(actions, isEmpty);
      expect(find.text('2 / 4'), findsOneWidget);
      expect(find.text('Awaiting permission'), findsOneWidget);
      await tester.tap(find.text('Set up VPN'));
      expect(actions, [SetupAction.permission]);

      final denied = waiting.copyWith(
        permission: PlatformPermissionResult(
          kind: PlatformPermissionKind.androidVpn,
          state: PlatformPermissionState.denied,
        ),
        failure: const SetupFailure('permission'),
      );
      await show(denied);
      expect(find.text('Permission not granted'), findsOneWidget);
      expect(
        find.textContaining('VPN permission is required.'),
        findsOneWidget,
      );

      final ready = waiting.copyWith(
        permission: PlatformPermissionResult(
          kind: PlatformPermissionKind.androidVpn,
          state: PlatformPermissionState.granted,
        ),
      );
      await show(ready, interface: true);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await show(ready);
      await tester.tap(find.text('Continue'));
      expect(actions.last, SetupAction.continueSystem);
    },
  );

  testWidgets(
    'server methods route individually and scan follows platform support',
    (tester) async {
      _mobile(tester);
      final imports = <ServerImportAction>[];
      for (final supportsScan in [false, true]) {
        await tester.pumpWidget(
          _app(
            SetupView(
              state: const SetupPageState(step: SetupStep.servers, busy: false),
              requiresInterface: false,
              supportsScan: supportsScan,
              onAction: (_) {},
              onAddServer: imports.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Scan QR code'),
          supportsScan ? findsOneWidget : findsNothing,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        final style = tester
            .widget<FilledButton>(find.byType(FilledButton))
            .style!;
        final palette = ColorManager.palette(
          tester.element(find.byType(SetupView)),
        );
        expect(
          style.backgroundColor!.resolve({WidgetState.disabled}),
          palette.border.withValues(alpha: .7),
        );
        expect(
          style.foregroundColor!.resolve({WidgetState.disabled}),
          palette.mutedForeground.withValues(alpha: .7),
        );
        expect(style.backgroundColor!.resolve({}), isNull);
        imports.clear();
        for (final label in [
          'Paste link',
          if (supportsScan) 'Scan QR code',
          'Add subscription',
          'Import file',
          'Add JSON manually',
        ]) {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
        }
        expect(imports, [
          ServerImportAction.paste,
          if (supportsScan) ServerImportAction.scan,
          ServerImportAction.subscription,
          ServerImportAction.file,
          ServerImportAction.json,
        ]);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('region selection is a route-local draft until Done', (
    tester,
  ) async {
    _mobile(tester);
    String? selected;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  selected = await context.push<String>('/region'),
              child: const Text('Open region'),
            ),
          ),
        ),
        GoRoute(
          path: '/region',
          builder: (context, _) => const SetupRegionPage(
            params: SetupRegionParams(['CN', 'RU', 'IR', 'US'], 'CN'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.material(Brightness.light, mobile: true),
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => ShadTheme(
          data: AppTheme.shad(Brightness.light, mobile: true),
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open region'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing);
    expect(tester.getSize(find.widgetWithText(TextButton, 'Back')).height, 38);
    await tester.enterText(find.byType(TextField), 'Russia');
    await tester.pumpAndSettle();
    expect(find.text('Mainland China'), findsNothing);
    await tester.tap(find.text('Russia').last);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('Open region'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Russia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(selected, 'RU');
    expect(tester.takeException(), isNull);
  });
}
