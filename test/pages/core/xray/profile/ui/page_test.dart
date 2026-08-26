import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/ui/controller.dart';
import 'package:onexray/pages/core/xray/profile/ui/page.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/config_map.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    eventBus = AppEventBus();
  });

  tearDown(() => eventBus.close());

  test('every supported root except name is represented in the UI', () {
    final roots = <String>{
      'inbounds',
      'outbounds',
      'routing',
      'dns',
      'fakeDns',
      'log',
      ...xrayProfileAdvancedRoots,
    };
    expect(roots, xrayConfigRootNames.difference({'name'}));
  });

  testWidgets('profile starts with raw-only inbounds and complete Raw JSON', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.textContaining('only common fields'), findsOneWidget);
    expect(find.text('Edit inbounds JSON'), findsOneWidget);
    expect(find.byTooltip('Raw JSON'), findsOneWidget);
    expect(find.text('TUN Mode'), findsNothing);
    expect(find.text('Additional Inbounds'), findsNothing);
  });

  testWidgets('routing exposes only domainStrategy and its root JSON', (
    tester,
  ) async {
    await _pumpPage(tester);
    await _selectSection(tester, 'Routing');

    expect(find.text('domainStrategy'), findsOneWidget);
    expect(find.text('Edit routing JSON'), findsOneWidget);
    expect(find.text('Custom Rules'), findsNothing);
  });

  testWidgets('new profile uses the TUN DNS server in the compact editor', (
    tester,
  ) async {
    final tunSettings = TunSettingsState()..tunDnsIPv4 = '9.9.9.9';
    await tunSettings.saveToPreferences();
    await _pumpPage(tester);
    await _selectSection(tester, 'DNS');

    expect(find.text('9.9.9.9'), findsOneWidget);
    expect(find.text('Edit dns JSON'), findsOneWidget);
    expect(find.text('Hosts'), findsNothing);
    expect(find.text('Global Policy'), findsNothing);
  });

  testWidgets('structured leaf edits retain root siblings', (tester) async {
    await _pumpPage(tester);
    final controller = tester
        .element(find.byType(SettingsPageScaffold))
        .read<XrayProfileUIController>();
    final before = controller.document['routing'] as Map<String, dynamic>;
    final siblings = Map<String, dynamic>.from(before)
      ..remove('domainStrategy');

    controller.updateDomainStrategy('AsIs');

    final after = controller.document['routing'] as Map<String, dynamic>;
    final retained = Map<String, dynamic>.from(after)..remove('domainStrategy');
    expect(retained, siblings);
    expect(after['domainStrategy'], 'AsIs');
  });

  testWidgets('advanced section keeps metrics and stats read-only', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpPage(tester);
    await _selectSection(tester, 'Advanced');

    for (final root in xrayProfileAdvancedRoots.where(
      (root) => !xrayProfileReadOnlyRoots.contains(root),
    )) {
      expect(find.text('Edit $root JSON'), findsOneWidget);
    }
    expect(find.text('Edit metrics JSON'), findsNothing);
    expect(find.text('Edit stats JSON'), findsNothing);
    expect(find.text('metrics'), findsOneWidget);
    expect(find.text('{"listen":"127.0.0.1:0"}'), findsOneWidget);
    expect(find.text('stats'), findsOneWidget);
    expect(find.text('{}'), findsOneWidget);
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadBlueColorScheme.light(),
          radius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: XrayProfileUIPage(
        params: XrayProfileUIParams(DBConstants.defaultId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectSection(WidgetTester tester, String title) async {
  final navigation = find.byType(
    SettingsSectionNavigation<XrayProfileUISection>,
  );
  final target = find.descendant(of: navigation, matching: find.text(title));
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}
