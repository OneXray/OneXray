import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/controller.dart';
import 'package:onexray/pages/launch/setup/selectors.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/servers/import/controller.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connection/runtime.dart';
import 'package:onexray/service/connection/settings.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:onexray/service/tun_settings/interface.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'privacy and permission stay explicit, then ready steps advance',
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
      expect(controller.state.step, SetupStep.servers);
      expect(service.savedRegion, 'RU');
      expect(service.finishes, 0);
    },
  );

  test(
    'ready startup finishes automatically when servers already exist',
    () async {
      final service = _SetupService()
        ..step = SetupStep.system
        ..granted = true
        ..hasNodes = true;
      final controller = SetupController(service: service);
      addTearDown(controller.close);
      await _idle(controller);
      expect(controller.state.step, SetupStep.complete);
      expect(service.finishes, 1);
      expect(service.permissionRequests, 0);
    },
  );

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
      expect(controller.state.step, SetupStep.region);
      expect(controller.state.region, isEmpty);
      expect(service.savedRegion, isNull);
      await controller.skipRegion();
      expect(controller.state.step, SetupStep.servers);
      expect(service.savedRegion, isNull);
      await controller.finish();
      expect(controller.state.step, SetupStep.complete);
    },
  );

  test(
    'local failures and denied permission stop automatic progress',
    () async {
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
    },
  );

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
    },
  );

  for (final interface in [false, true]) {
    testWidgets(
      'selecting ${interface ? 'interface' : 'region'} advances without confirmation',
      (tester) async {
        final service =
            _SetupService(
                platform: interface
                    ? ConnectionPlatform.windows
                    : ConnectionPlatform.ios,
              )
              ..step = SetupStep.system
              ..granted = true
              ..suggestedRegion = interface ? 'RU' : null;
        final controller = SetupController(service: service);
        addTearDown(controller.close);
        await _idle(controller);
        expect(
          controller.state.step,
          interface ? SetupStep.system : SetupStep.region,
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => interface
                      ? controller.chooseInterface(context)
                      : controller.chooseRegion(context),
                  child: const Text('Choose'),
                ),
              ),
            ),
            ...RouterPath.router.configuration.routes
                .whereType<GoRoute>()
                .where(
                  (route) =>
                      route.path == '/setup/interface' ||
                      route.path == '/setup/region',
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (_, child) =>
                ShadTheme(data: AppTheme.shad(Brightness.light), child: child!),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose'));
        await tester.pumpAndSettle();
        expect(find.text('Done'), findsNothing);
        await tester.tap(find.text(interface ? 'Ethernet' : 'Russia').last);
        await tester.pumpAndSettle();
        expect(find.byType(SetupRegionPage), findsNothing);
        expect(find.byType(SetupInterfacePage), findsNothing);
        expect(controller.state.step, SetupStep.servers);
        expect(service.savedRegion, 'RU');
        if (interface) expect(service.savedInterface, 'Ethernet');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cancelled import stays; available nodes finish immediately', (
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
  _SetupService({super.platform});
  SetupStep step = SetupStep.welcome;
  bool granted = false;
  bool localFailure = false;
  bool hasNodes = false;
  String? suggestedRegion = 'RU';
  String? savedRegion;
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
      ConnectionConfiguration();
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
    savedInterface = name;
    step = SetupStep.region;
  }

  @override
  Future<String?> suggestRegion() async => suggestedRegion;
  @override
  Future<void> continueRegion(String? region) async {
    savedRegion = region;
    step = SetupStep.servers;
  }

  @override
  Future<bool> hasServers() async => hasNodes;
  @override
  Future<void> finish() async {
    finishes++;
    step = SetupStep.complete;
  }
}
