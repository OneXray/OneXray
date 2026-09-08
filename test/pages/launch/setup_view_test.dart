import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:onexray/pages/launch/setup/page.dart';
import 'package:onexray/pages/connect/routing/smart/regions.dart';
import 'package:onexray/pages/launch/setup/widgets.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:onexray/service/connect/routing/region_catalog.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  bool mobile = true,
}) => MaterialApp(
  theme: AppTheme.material(Brightness.light, mobile: mobile),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalePolicy.localizationsDelegates,
  builder: (context, child) => ShadTheme(
    data: AppTheme.shad(Brightness.light, mobile: mobile),
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

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1160, 688);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
  });
  testWidgets('system step identifies missing local network permission', (
    tester,
  ) async {
    _mobile(tester);
    final actions = <SetupAction>[];
    await tester.pumpWidget(
      _app(
        SetupView(
          state: SetupPageState(
            step: SetupStep.system,
            busy: false,
            localReady: true,
            permission: PlatformPermissionResult(
              kind: PlatformPermissionKind.androidLocalNetwork,
              state: PlatformPermissionState.notDetermined,
            ),
          ),
          requiresInterface: false,
          supportsScan: true,
          onAction: actions.add,
          onAddServer: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final hint = find.text(
      'Allow access to devices and services on the local network.',
    );
    expect(hint, findsOneWidget);
    expect(find.text('VPN permission'), findsNothing);
    await tester.tap(hint);
    expect(actions, [SetupAction.permission]);
    expect(tester.takeException(), isNull);
  });

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
    'system states require Continue after permission and interface setup',
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
      expect(find.text('Continue'), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
      await show(ready);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(actions.last, SetupAction.continueSystem);

      await show(
        ready.copyWith(
          permission: PlatformPermissionResult(
            kind: PlatformPermissionKind.appleVpn,
            state: PlatformPermissionState.notRequired,
          ),
        ),
      );
      expect(find.text('Set up VPN'), findsNothing);
      expect(
        find.text('Allow OneXray to add a VPN configuration.'),
        findsNothing,
      );
      expect(find.text('Authorized'), findsNothing);
      await tester.tap(find.text('Continue'));
      expect(actions.last, SetupAction.continueSystem);
    },
  );

  testWidgets('suggested region waits for Continue or Skip', (tester) async {
    _mobile(tester);
    final actions = <SetupAction>[];
    Future<void> show(List<String>? regions) async {
      await tester.pumpWidget(
        _app(
          SetupView(
            state: SetupPageState(
              step: SetupStep.region,
              busy: false,
              regions: regions,
              regionCodes: const ['CN', 'RU'],
            ),
            requiresInterface: false,
            supportsScan: true,
            onAction: actions.add,
            onAddServer: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(null);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    await show(['RU']);
    expect(find.text('Russia'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.tap(find.text('Skip'));
    expect(actions, [SetupAction.continueRegion, SetupAction.skipRegion]);
    final l = AppLocalizations.of(tester.element(find.byType(SetupView)))!;
    await show([]);
    expect(find.text(l.prototypeNoDirectRegions), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'configured servers expose Home without a speed-test loading indicator',
    (tester) async {
      _mobile(tester);
      final actions = <SetupAction>[];
      AppEventBus.instance.updatePinging(true);
      await tester.pumpWidget(
        _app(
          SetupView(
            state: const SetupPageState(
              step: SetupStep.servers,
              busy: false,
              hasServers: true,
            ),
            requiresInterface: false,
            supportsScan: true,
            onAction: actions.add,
            onAddServer: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Servers added. You are ready to go to Home.'),
        findsOneWidget,
      );
      expect(find.text('Add later'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Go to Home'));
      expect(actions, [SetupAction.finish]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop setup uses the full stepper and distributed footer', (
    tester,
  ) async {
    _desktop(tester);
    await tester.pumpWidget(
      _app(
        SetupView(
          state: SetupPageState(
            step: SetupStep.system,
            busy: false,
            localReady: true,
            permission: PlatformPermissionResult(
              kind: PlatformPermissionKind.appleVpn,
              state: PlatformPermissionState.notDetermined,
            ),
          ),
          requiresInterface: false,
          supportsScan: false,
          onAction: (_) {},
          onAddServer: (_) {},
        ),
        mobile: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome & privacy'), findsOneWidget);
    expect(find.text('System setup'), findsOneWidget);
    expect(find.text('This process will not start the VPN.'), findsOneWidget);
    expect(find.text('Set up VPN'), findsNWidgets(2));
    final back = tester.getRect(find.widgetWithText(OutlinedButton, 'Back'));
    final next = tester.getRect(
      find.widgetWithText(FilledButton, 'Set up VPN'),
    );
    expect(back.width, 210);
    expect(next.width, 210);
    expect(back.left, 40);
    expect(next.right, 1120);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Set up VPN'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

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
        expect(find.text('Go to home'), findsNothing);
        expect(find.text('Add later'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
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

  testWidgets(
    'shared region page supports search, single selection, Done and Back',
    (tester) async {
      _mobile(tester);
      List<String>? selected;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    selected = await context.push<List<String>>('/region'),
                child: const Text('Open region'),
              ),
            ),
          ),
          GoRoute(
            path: '/region',
            builder: (context, _) => DirectRegionsPage(
              selectedCodes: selected ?? const ['CN'],
              loadRegions: () async => RegionCatalog.fromJson(
                {
                  'geosite': <String, dynamic>{},
                  'geoip': {
                    for (final code in ['CN', 'RU', 'IR', 'US']) code: [code],
                  },
                },
                geositeCodes: [],
                geoipCodes: ['CN', 'RU', 'IR', 'US'],
              ),
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
          localizationsDelegates: AppLocalePolicy.localizationsDelegates,
          builder: (context, child) => ShadTheme(
            data: AppTheme.shad(Brightness.light, mobile: true),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open region'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Russia');
      await tester.pumpAndSettle();
      expect(find.text('Mainland China'), findsNothing);
      await tester.tap(find.text('Russia').last);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      await tester.tap(find.text('Open region'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Russia'));
      await tester.pumpAndSettle();
      expect(find.byType(DirectRegionsPage), findsOneWidget);
      expect(selected, isNull);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(selected, ['RU']);
      await tester.tap(find.text('Open region'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear all'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
