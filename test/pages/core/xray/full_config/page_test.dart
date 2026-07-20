import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/full_config/controller.dart';
import 'package:onexray/pages/core/xray/full_config/page.dart';
import 'package:onexray/pages/core/xray/full_config/params.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
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

  tearDown(() async {
    await eventBus.close();
  });

  Widget app() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadBlueColorScheme.light(),
          radius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: XrayFullConfigPage(
        params: XrayFullConfigParams(DBConstants.defaultId),
      ),
    );
  }

  testWidgets('full config sections render in the shared desktop workspace', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Primary Proxy'), findsOneWidget);
    expect(find.text('Custom Outbounds'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Edit Outbounds'), findsNothing);

    await tester.tap(find.text('Routing').first);
    await tester.pump();

    expect(find.text('Strategy'), findsOneWidget);
    expect(find.text('System Rules'), findsOneWidget);

    await tester.tap(find.text('DNS').first);
    await tester.pump();

    expect(find.text('Hosts'), findsOneWidget);
    expect(find.text('Servers'), findsOneWidget);
  });

  testWidgets('desktop full config detail stays aligned to workspace top', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final navigation = find.byType(
      SettingsSectionNavigation<XrayFullConfigSection>,
    );
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Routing')),
    );
    await tester.pumpAndSettle();

    final detailScroll = find.descendant(
      of: find.byType(SettingsPageScroll),
      matching: find.byType(SingleChildScrollView),
    );
    expect(detailScroll, findsOneWidget);
    expect(
      tester.getTopLeft(detailScroll).dy,
      closeTo(tester.getTopLeft(navigation).dy, 0.1),
    );
  });

  testWidgets('full config uses the scrollable compact section navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pump();

    final navigation = find.byType(
      SettingsSectionNavigation<XrayFullConfigSection>,
    );
    expect(navigation, findsOneWidget);
    expect(
      find.descendant(
        of: navigation,
        matching: find.byIcon(LucideIcons.chevronLeft),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: navigation,
        matching: find.byIcon(LucideIcons.chevronRight),
      ),
      findsNothing,
    );

    final scroller = find.descendant(
      of: navigation,
      matching: find.byType(SingleChildScrollView),
    );
    expect(scroller, findsOneWidget);

    final outboundsTitle = tester.widget<Text>(
      find.descendant(of: navigation, matching: find.text('Outbounds')),
    );
    expect(outboundsTitle.overflow, isNull);

    await tester.drag(scroller, const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('DNS')).hitTestable(),
    );
    await tester.pump();

    expect(find.text('Hosts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new full config uses the TUN DNS server by default', (
    tester,
  ) async {
    final tunSettings = TunSettingsState()..tunDnsIPv4 = '9.9.9.9';
    await tunSettings.saveToPreferences();

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('DNS').first);
    await tester.pumpAndSettle();

    expect(find.text('9.9.9.9'), findsOneWidget);
  });
}
