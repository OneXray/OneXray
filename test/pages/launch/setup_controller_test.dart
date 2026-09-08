import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:onexray/pages/launch/setup/controller.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/launch/setup/view.dart';
import 'package:onexray/pages/connect/routing/smart/regions.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/advanced/platform_policy.dart';
import 'package:onexray/service/connect/runtime.dart';
import 'package:onexray/service/connect/settings.dart';
import 'package:onexray/service/connect/routing/region_catalog.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:onexray/service/advanced/tunnel/interface.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    final bus = AppEventBus();
    addTearDown(bus.close);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'privacy, permission and ready steps require explicit actions',
    () async {
      final service = _SetupService();
      final controller = SetupController(service: service);
      addTearDown(controller.close);
      await _idle(controller);
      expect(controller.state.step, SetupStep.welcome);
      expect(service.permissionRequests, 0);
      await controller.acceptPrivacy();
      expect(controller.state.step, SetupStep.system);
      expect(service.permissionRequests, 0);
      service.granted = true;
      await controller.requestPermission();
      expect(service.permissionRequests, 1);
      expect(controller.state.step, SetupStep.system);
      expect(service.savedRegion, isNull);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _idle(controller);
      expect(controller.state.step, SetupStep.system);
      await controller.continueSystem();
      expect(controller.state.step, SetupStep.region);
      expect(controller.state.regions, ['RU']);
      expect(service.savedRegion, isNull);
      await controller.continueRegion();
      expect(controller.state.step, SetupStep.servers);
      expect(service.savedRegion, ['RU']);
      expect(service.finishes, 0);
    },
  );

  test('ready startup and existing servers never skip setup steps', () async {
    final service = _SetupService()
      ..step = SetupStep.system
      ..granted = true
      ..hasNodes = true;
    final controller = SetupController(service: service);
    addTearDown(controller.close);
    await _idle(controller);
    expect(controller.state.step, SetupStep.system);
    expect(service.finishes, 0);
    await controller.continueSystem();
    expect(controller.state.step, SetupStep.region);
    expect(service.savedRegion, isNull);
    await controller.continueRegion();
    expect(controller.state.step, SetupStep.servers);
    expect(controller.state.hasServers, isTrue);
    expect(service.finishes, 0);
    await controller.finish();
    expect(controller.state.step, SetupStep.complete);
    expect(service.finishes, 1);
    expect(service.permissionRequests, 0);
  });

  test(
    'unrecognized region never uses default CN; Skip stays available',
    () async {
      final service = _SetupService()
        ..step = SetupStep.system
        ..granted = true
        ..suggestedRegion = 'UNKNOWN';
      final controller = SetupController(service: service);
      addTearDown(controller.close);
      await _idle(controller);
      await controller.continueSystem();
      expect(controller.state.step, SetupStep.region);
      expect(controller.state.regions, isNull);
      expect(service.savedRegion, isNull);
      await controller.continueRegion();
      expect(controller.state.step, SetupStep.region);
      expect(service.savedRegion, isNull);
      await controller.skipRegion();
      expect(controller.state.step, SetupStep.servers);
      expect(service.savedRegion, isNull);
      await controller.finish();
      expect(controller.state.step, SetupStep.complete);
    },
  );

  test(
    'nodes added outside setup update readiness without finishing',
    () async {
      final service = _SetupService()
        ..step = SetupStep.servers
        ..granted = true;
      final controller = SetupController(service: service);
      addTearDown(controller.close);
      await _idle(controller);
      expect(controller.state.step, SetupStep.servers);
      final ready = controller.stream.firstWhere(
        (state) => state.hasServers && !state.busy,
      );
      service.hasNodes = true;
      await ready;
      expect(controller.state.step, SetupStep.servers);
      expect(service.finishes, 0);
      await controller.finish();
      expect(service.finishes, 1);
    },
  );

  test('local failures and denied permission keep the required step', () async {
    final service = _SetupService()
      ..step = SetupStep.system
      ..localFailure = true;
    final controller = SetupController(service: service);
    addTearDown(controller.close);
    await _idle(controller);
    expect(controller.state.failure?.component, 'local');
    expect(controller.state.step, SetupStep.system);
    service.localFailure = false;
    await controller.requestPermission();
    expect(controller.state.failure?.component, 'permission');
    expect(controller.state.step, SetupStep.system);
    expect(service.finishes, 0);
  });

  test(
    'revoked permission stays on System even when progress was saved later',
    () async {
      final service = _SetupService()..step = SetupStep.region;
      final controller = SetupController(service: service);
      addTearDown(controller.close);
      await _idle(controller);
      expect(controller.state.step, SetupStep.system);
      await controller.requestPermission();
      expect(controller.state.step, SetupStep.system);
      expect(service.savedRegion, isNull);
      expect(service.finishes, 0);
      service.granted = true;
      await controller.requestPermission();
      expect(controller.state.step, SetupStep.system);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _idle(controller);
      expect(controller.state.step, SetupStep.system);
      await controller.continueSystem();
      expect(controller.state.step, SetupStep.region);
      expect(service.savedRegion, isNull);
    },
  );

  for (final (platform, savedInterface) in [
    (ConnectionPlatform.ios, ''),
    (ConnectionPlatform.windows, ''),
    (ConnectionPlatform.linux, ''),
    (ConnectionPlatform.windows, 'Missing Ethernet'),
    (ConnectionPlatform.linux, 'Missing Ethernet'),
  ]) {
    final interface = platform != ConnectionPlatform.ios;
    testWidgets(
      'selecting ${interface ? 'interface' : 'region'} on ${platform.name} waits for Continue'
      ' (saved interface: "$savedInterface")',
      (tester) async {
        tester.view.physicalSize = const Size(1160, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = _SetupService(platform: platform)
          ..step = SetupStep.system
          ..granted = true
          ..savedInterface = savedInterface
          ..suggestedRegion = interface ? 'RU' : null;
        final controller = SetupController(service: service);
        addTearDown(controller.close);
        await _idle(controller);
        expect(controller.state.step, SetupStep.system);
        if (!interface || savedInterface.isNotEmpty) {
          await controller.continueSystem();
        }
        expect(
          controller.state.step,
          interface ? SetupStep.system : SetupStep.region,
        );
        if (savedInterface.isNotEmpty) {
          expect(controller.state.failure?.component, 'interface');
          expect(controller.state.interfaceName, savedInterface);
          expect(controller.state.busy, isFalse);
        }
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) =>
                  BlocBuilder<SetupController, SetupPageState>(
                    bloc: controller,
                    builder: (context, state) => SetupView(
                      state: state,
                      requiresInterface: service.requiresInterface,
                      supportsScan: false,
                      failureText: state.failure == null
                          ? null
                          : controller.failureText(
                              AppLocalizations.of(context)!,
                            ),
                      onAction: (action) =>
                          controller.handleAction(context, action),
                      onAddServer: (_) => fail('No import expected'),
                    ),
                  ),
            ),
            ...RouterPath.router.configuration.routes
                .whereType<GoRoute>()
                .where(
                  (route) =>
                      route.path == '/setup/interface' ||
                      route.path == '/setup/region',
                )
                .map(
                  (route) => route.path == '/setup/region'
                      ? GoRoute(
                          path: route.path,
                          redirect: route.redirect,
                          builder: (context, state) {
                            final page = route.builder!(
                              context,
                              state,
                            ) as DirectRegionsPage;
                            return DirectRegionsPage(
                              selectedCodes: page.selectedCodes,
                              loadRegions: () async => RegionCatalog.fromJson(
                                {
                                  'geosite': <String, dynamic>{},
                                  'geoip': {
                                    for (final code in ['CN', 'RU', 'US'])
                                      code: [code],
                                  },
                                },
                                geositeCodes: [],
                                geoipCodes: ['CN', 'RU', 'US'],
                              ),
                            );
                          },
                        )
                      : route,
                ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalePolicy.localizationsDelegates,
            builder: (_, child) =>
                ShadTheme(data: AppTheme.shad(Brightness.light), child: child!),
          ),
        );
        await tester.pumpAndSettle();
        if (savedInterface.isNotEmpty) {
          expect(find.text(savedInterface), findsOneWidget);
          expect(find.text('Continue'), findsOneWidget);
        }
        await tester.tap(
          find
              .text(
                interface
                    ? 'Xray outbound interface'
                    : 'Choose your country or region',
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(interface ? SetupInterfacePage : DirectRegionsPage),
          findsOneWidget,
        );
        expect(find.text('Done'), interface ? findsNothing : findsOneWidget);
        await tester.tap(find.text(interface ? 'Ethernet' : 'Russia').last);
        await tester.pumpAndSettle();
        if (!interface) {
          expect(find.byType(DirectRegionsPage), findsOneWidget);
          expect(controller.state.regions, isNull);
          await tester.tap(find.text('Mainland China'));
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          expect(controller.state.regions, ['CN']);
        }
        expect(find.byType(DirectRegionsPage), findsNothing);
        expect(find.byType(SetupInterfacePage), findsNothing);
        expect(
          controller.state.step,
          interface ? SetupStep.system : SetupStep.region,
        );
        expect(controller.state.failure, isNull);
        expect(service.savedRegion, isNull);
        if (interface) {
          expect(service.savedInterface, savedInterface);
          controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await _idle(controller);
          await tester.pumpAndSettle();
          expect(controller.state.step, SetupStep.system);
          expect(controller.state.interfaceName, 'Ethernet');
          await tester.tap(find.text('Continue'));
          await tester.pumpAndSettle();
          expect(controller.state.step, SetupStep.region);
          expect(service.savedInterface, 'Ethernet');
          expect(service.savedRegion, isNull);
        }
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(controller.state.step, SetupStep.servers);
        expect(service.savedRegion, interface ? ['RU'] : ['CN']);
        if (interface) expect(service.savedInterface, 'Ethernet');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cancelled and successful imports stay until explicit finish', (
    tester,
  ) async {
    final service = _SetupService()
      ..step = SetupStep.servers
      ..granted = true;
    final controller = SetupController(service: service);
    addTearDown(controller.close);
    await _idle(controller);
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final context = tester.element(find.byType(Scaffold));
    await controller.addServers(
      context,
      ServerImportAction.file,
      (_, _) async {},
    );
    expect(controller.state.step, SetupStep.servers);
    await controller.addServers(context, ServerImportAction.file, (_, _) async {
      service.hasNodes = true;
    });
    expect(controller.state.step, SetupStep.servers);
    expect(controller.state.hasServers, isTrue);
    expect(service.finishes, 0);
    await controller.finish();
    expect(controller.state.step, SetupStep.complete);
    expect(service.finishes, 1);
  });
}

Future<void> _idle(SetupController controller) async {
  if (controller.state.busy) {
    await controller.stream.firstWhere((state) => !state.busy);
  }
}

// Controller checks only. Real persistence and preflight are covered by setup_test.
class _SetupService extends SetupService {
  _SetupService({super.platform = ConnectionPlatform.ios}) {
    addTearDown(_nodes.close);
  }
  SetupStep step = SetupStep.welcome;
  bool granted = false;
  bool localFailure = false;
  final _nodes = StreamController<bool>.broadcast(sync: true);
  bool _hasNodes = false;
  set hasNodes(bool value) {
    _hasNodes = value;
    _nodes.add(value);
  }

  String? suggestedRegion = 'RU';
  List<String>? savedRegion;
  String? savedInterface;
  int permissionRequests = 0;
  int finishes = 0;

  @override
  Future<SetupStep> currentStep() async => step;
  @override
  Future<void> acceptPrivacy() async {
    step = SetupStep.system;
  }

  @override
  Future<void> prepareLocal() async {
    if (localFailure) throw const SetupFailure('local');
  }

  @override
  Future<ConnectionConfiguration> configuration() async =>
      ConnectionConfiguration(
        policy: PlatformPolicy.fromJson({
          'xrayOutboundInterfaceName': savedInterface ?? '',
        }),
      );
  @override
  Future<List<String>> regionCodes() async => ['CN', 'RU', 'US'];
  @override
  Future<PlatformPermissionResult> checkPermission({
    bool request = false,
  }) async {
    if (request) permissionRequests++;
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.appleVpn,
      state: granted
          ? PlatformPermissionState.granted
          : PlatformPermissionState.denied,
    );
  }

  @override
  Future<List<OutboundInterfaceOption>> interfaces() async => [
    const OutboundInterfaceOption('Ethernet', ['192.0.2.2'], true),
  ];
  @override
  Future<void> continueSystem(String name) async {
    if (requiresInterface &&
        !(await interfaces()).any((item) => item.name == name)) {
      throw const SetupFailure('interface');
    }
    savedInterface = name;
    step = SetupStep.region;
  }

  @override
  Future<String?> suggestRegion() async => suggestedRegion;
  @override
  Future<void> continueRegion(List<String>? regions) async {
    savedRegion = regions;
    step = SetupStep.servers;
  }

  @override
  Stream<bool> watchHasServers() {
    scheduleMicrotask(() => _nodes.add(_hasNodes));
    return _nodes.stream;
  }

  @override
  Future<void> finish() async {
    finishes++;
    step = SetupStep.complete;
  }
}
