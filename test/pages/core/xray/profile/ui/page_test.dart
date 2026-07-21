import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/dns/view.dart';
import 'package:onexray/pages/core/xray/profile/ui/page.dart';
import 'package:onexray/pages/core/xray/profile/ui/controller.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
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

  tearDown(() => eventBus.close());

  testWidgets('profile sections render their editors inline', (tester) async {
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
    await tester.pump();

    expect(find.text('TUN Mode'), findsOneWidget);
    expect(find.text('Internal'), findsOneWidget);
    expect(find.text('Proxy Mode'), findsNothing);

    await tester.tap(find.text('Outbounds').first);
    await tester.pump();

    expect(find.text('Final Outbound'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Edit Outbounds'), findsNothing);
  });

  testWidgets('desktop profile detail stays aligned to the workspace top', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    final navigation = find.byType(
      SettingsSectionNavigation<XrayProfileUISection>,
    );
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Log')),
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

  testWidgets('new profile uses the TUN DNS server by default', (tester) async {
    final tunSettings = TunSettingsState()..tunDnsIPv4 = '9.9.9.9';
    await tunSettings.saveToPreferences();

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

    await tester.tap(find.text('DNS').first);
    await tester.pumpAndSettle();

    expect(find.text('9.9.9.9'), findsOneWidget);
  });

  testWidgets('profile compact navigation scrolls without arrow buttons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    final navigation = find.byType(
      SettingsSectionNavigation<XrayProfileUISection>,
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

    await tester.drag(scroller, const Offset(-320, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('DNS')).hitTestable(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hosts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DNS server list forwards drag gestures to the page scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    final navigation = find.byType(
      SettingsSectionNavigation<XrayProfileUISection>,
    );
    final navigationScroller = find.descendant(
      of: navigation,
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(navigationScroller, const Offset(-320, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('DNS')).hitTestable(),
    );
    await tester.pumpAndSettle();

    final controller = tester
        .element(find.byType(DnsView))
        .read<XrayProfileUIController>();
    for (var index = 0; index < 10; index++) {
      controller.appendDnsServer();
    }
    await tester.pumpAndSettle();

    final hostsTitle = find.text('Hosts');
    final hostsTopBefore = tester.getTopLeft(hostsTitle).dy;
    final firstServer = find
        .descendant(
          of: find.byType(ReorderableListView),
          matching: find.text(
            controller.profileState.dns.servers.first.address,
          ),
        )
        .first;

    await tester.drag(firstServer, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(hostsTitle).dy, lessThan(hostsTopBefore));
    expect(tester.takeException(), isNull);
  });
}
