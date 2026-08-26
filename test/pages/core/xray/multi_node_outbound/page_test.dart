import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/multi_node_outbound/controller.dart';
import 'package:onexray/pages/core/xray/multi_node_outbound/outbounds/view.dart';
import 'package:onexray/pages/core/xray/multi_node_outbound/page.dart';
import 'package:onexray/pages/core/xray/multi_node_outbound/params.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/outbound/map.dart';
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
      home: XrayMultiNodeOutboundPage(
        params: XrayMultiNodeOutboundParams(DBConstants.defaultId),
      ),
    );
  }

  testWidgets('Multi-node Outbound exposes only its three supported roots', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('Multi-node Outbound'), findsOneWidget);
    expect(find.text('Primary Proxy'), findsOneWidget);
    expect(find.text('Custom Outbounds'), findsOneWidget);
    expect(find.text('System'), findsNothing);
    expect(
      find.text(
        'Multi-node Outbound only stores outbounds, dns, and routing. Edit advanced settings inside these fields with root JSON or Raw JSON.',
      ),
      findsOneWidget,
    );
    final navigation = tester
        .widget<SettingsSectionNavigation<XrayMultiNodeOutboundSection>>(
          find.byType(SettingsSectionNavigation<XrayMultiNodeOutboundSection>),
        );
    expect(navigation.items.map((item) => item.value), const [
      XrayMultiNodeOutboundSection.outbounds,
      XrayMultiNodeOutboundSection.routing,
      XrayMultiNodeOutboundSection.dns,
    ]);

    await tester.tap(find.text('Routing').first);
    await tester.pump();

    expect(find.text('Strategy'), findsOneWidget);
    expect(find.text('System Rules'), findsNothing);
    expect(find.text('Edit routing JSON'), findsOneWidget);

    await tester.tap(find.text('DNS').first);
    await tester.pump();

    expect(find.text('Hosts'), findsNothing);
    expect(find.text('Servers'), findsOneWidget);
    expect(find.text('Edit dns JSON'), findsOneWidget);
  });

  testWidgets(
    'desktop Multi-node Outbound detail stays aligned to workspace top',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final navigation = find.byType(
        SettingsSectionNavigation<XrayMultiNodeOutboundSection>,
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
    },
  );

  testWidgets('Multi-node Outbound uses compact section navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pump();

    final navigation = find.byType(
      SettingsSectionNavigation<XrayMultiNodeOutboundSection>,
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

    expect(find.text('Edit dns JSON'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new Multi-node Outbound copies outbounds and inherits DNS', (
    tester,
  ) async {
    final tunSettings = TunSettingsState()..tunDnsIPv4 = '9.9.9.9';
    await tunSettings.saveToPreferences();

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SettingsPageScaffold));
    final controller = BlocProvider.of<XrayMultiNodeOutboundController>(
      context,
    );
    expect(controller.draft.keys, <String>['name', 'outbounds']);
    final servers = controller.dnsServers;
    expect(
      servers.whereType<Map>().map((server) => server['address']),
      contains('tcp://9.9.9.9'),
    );
    await tester.tap(find.text('DNS').first);
    await tester.pumpAndSettle();
    expect(find.text('tcp://9.9.9.9'), findsOneWidget);
    await tester.tap(find.text('tcp://9.9.9.9'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    final fields = find.descendant(
      of: dialog,
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), '1.1.1.1');
    await tester.enterText(fields.at(1), '5353');
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.pumpAndSettle();

    final editedDns = controller.draft['dns']! as Map<String, dynamic>;
    final editedServer = (editedDns['servers']! as List<dynamic>).first as Map;
    expect(editedServer['address'], '1.1.1.1');
    expect(editedServer['port'], 5353);
    expect(editedServer['queryStrategy'], 'UseIPv4');
  });

  testWidgets('root Raw editor copies an inherited root only when saved', (
    tester,
  ) async {
    XrayRawEditParams? rawParams;
    final router = GoRouter(
      initialLocation: '/home/xray-full-config',
      routes: [
        GoRoute(
          path: '/home/xray-full-config',
          builder: (_, _) => XrayMultiNodeOutboundPage(
            params: XrayMultiNodeOutboundParams(DBConstants.defaultId),
          ),
        ),
        GoRoute(
          path: '/home/xray-raw-edit',
          builder: (context, state) {
            rawParams = state.extra! as XrayRawEditParams;
            return Scaffold(
              body: Column(
                children: [
                  TextButton(
                    key: const Key('cancel-raw'),
                    onPressed: context.pop,
                    child: const Text('Cancel Raw'),
                  ),
                  TextButton(
                    key: const Key('save-raw'),
                    onPressed: () => context.pop(
                      '{"routing":{"domainStrategy":"IPIfNonMatch"}}',
                    ),
                    child: const Text('Save Raw'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadBlueColorScheme.light(),
            radius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageContext = tester.element(find.byType(SettingsPageScaffold));
    final controller = BlocProvider.of<XrayMultiNodeOutboundController>(
      pageContext,
    );
    expect(controller.draft, isNot(contains('routing')));

    await tester.tap(find.text('Routing').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit routing JSON'));
    await tester.pumpAndSettle();

    expect(rawParams!.text, contains('"routing"'));
    expect(controller.draft, isNot(contains('routing')));

    await tester.tap(find.byKey(const Key('cancel-raw')));
    await tester.pumpAndSettle();
    expect(controller.draft, isNot(contains('routing')));

    await tester.tap(find.text('Edit routing JSON'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-raw')));
    await tester.pumpAndSettle();

    expect(controller.draft['routing'], {'domainStrategy': 'IPIfNonMatch'});
  });

  testWidgets('compact outbound rows preserve space for node names', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final primaryProxy = newOutboundMap(name: 'Singapore-Premium-Reality');
    final customOutbound = newOutboundMap(
      name: 'Seattle-Standard-XHTTP',
      tag: 'custom1',
    )..['appUnprojected'] = <String, dynamic>{'keep': true};
    Map<String, dynamic>? editedOutbound;
    Map<String, dynamic>? deletedOutbound;

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
        home: Scaffold(
          body: XrayMultiNodeOutboundOutboundsView(
            primaryProxy: primaryProxy,
            customOutbounds: [customOutbound],
            onEditPrimaryProxy: () {},
            onImportPrimaryProxy: () {},
            onAddCustomOutbound: () {},
            onImportCustomOutbound: () {},
            onEditCustomOutbound: (outbound) => editedOutbound = outbound,
            onDeleteCustomOutbound: (outbound) => deletedOutbound = outbound,
            onEditRawJson: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final name in [
      'Singapore-Premium-Reality',
      'Seattle-Standard-XHTTP',
    ]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      expect(paragraph.didExceedMaxLines, isFalse, reason: name);
    }
    expect(find.text('vless · raw · custom1'), findsOneWidget);
    expect(find.byIcon(LucideIcons.pencil), findsNothing);
    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);

    await tester.tap(find.text('Seattle-Standard-XHTTP'));
    await tester.pump();
    expect(identical(editedOutbound, customOutbound), true);

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pump();
    expect(identical(deletedOutbound, customOutbound), true);
    expect(customOutbound['appUnprojected'], <String, dynamic>{'keep': true});
  });
}
