import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/menus.dart';
import 'package:onexray/pages/servers/view.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/shared/widgets/responsive_content.dart';
import 'package:onexray/pages/shared/widgets/page_empty_state.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/ping/batch.dart';
import 'package:onexray/service/shared/ping/service.dart';
import 'package:onexray/service/servers/outbound/state_db.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadTheme, ShadToaster, ShadToast;

class _Controller extends ServersController {
  _Controller({
    required super.database,
    required super.coordinator,
    super.ping,
  });

  bool? browsedOnMobile;
  bool helpOpened = false;
  bool addOpened = false;

  @override
  Future<void> browse(
    BuildContext context,
    ServerGroup group, {
    required bool mobile,
  }) async {
    browsedOnMobile = mobile;
    activeGroupId = group.id;
    changed();
  }

  @override
  Future<void> openServerHelp(BuildContext context) async {
    helpOpened = true;
  }

  @override
  Future<void> addServers(BuildContext context) async {
    addOpened = true;
  }
}

CoreConfigData _server(int id, String country, {bool favorite = false}) =>
    CoreConfigData(
      id: id,
      name: 'Node $id',
      type: 'outbound',
      tags: 'vless,xhttp,tls',
      data: base64Encode(
        utf8.encode(
          jsonEncode({
            'tag': 'Node $id',
            'protocol': 'vless',
            'streamSettings': {'network': 'xhttp', 'security': 'tls'},
          }),
        ),
      ),
      delay: id * 20,
      subId: 0,
      countryCode: country,
      favorite: favorite,
    );

void main() {
  late AppDatabase db;
  late ConnectionCoordinator coordinator;
  late _Controller controller;
  late ScrollController scroll;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final bus = AppEventBus();
    addTearDown(bus.close);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    coordinator = ConnectionCoordinator(database: db);
    controller = _Controller(database: db, coordinator: coordinator)
      ..servers = [_server(1, 'JP', favorite: true), _server(2, 'SG')];
    scroll = ScrollController();
  });

  tearDown(() async {
    scroll.dispose();
    await controller.close();
    coordinator.dispose();
    await db.close();
  });

  Future<void> pumpBrowser(
    WidgetTester tester,
    double width, {
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
    bool groupPage = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final mobile = width <= AppLayout.mobileBreakpoint;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(brightness, mobile: mobile),
        locale: locale,
        localizationsDelegates: AppLocalePolicy.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => ShadTheme(
          data: AppTheme.shad(brightness),
          child: ShadToaster(child: child!),
        ),
        home: Scaffold(
          body: Row(
            children: [
              if (!mobile)
                SizedBox(
                  width: width <= AppLayout.compactDesktopBreakpoint
                      ? AppLayout.compactSidebarWidth
                      : AppLayout.desktopSidebarWidth,
                ),
              Expanded(
                child: ResponsiveContent(
                  child: BlocBuilder<_Controller, ConnectPageState>(
                    bloc: controller,
                    builder: (context, _) => groupPage
                        ? ServerGroupView(
                            controller: controller,
                            group: controller
                                .groups(AppLocalizations.of(context)!)
                                .first,
                          )
                        : ServerBrowser(controller: controller, scroll: scroll),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final width in [427.0, 1160.0]) {
      testWidgets(
        'node latency colors preserve metadata ($brightness, $width)',
        (tester) async {
          final palette = AppColorTokens.fallback(brightness).palette;
          final samples = [
            (0, palette.runningBadge),
            (500, palette.runningBadge),
            (501, palette.restartingText),
            (1000, palette.restartingText),
            (1001, palette.primaryHover),
            (PingDelayConstants.unknown, palette.mutedForeground),
            (PingDelayConstants.error, palette.mutedForeground),
            (PingDelayConstants.timeout, palette.mutedForeground),
          ];
          controller.servers = [
            for (final (index, (delay, _)) in samples.indexed)
              _server(index + 1, 'JP').copyWith(delay: delay),
          ];
          await pumpBrowser(
            tester,
            width,
            brightness: brightness,
            groupPage: true,
          );
          final l = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
          for (final (index, (delay, color)) in samples.indexed) {
            final label = controller.health(l, controller.servers[index]);
            final prefix = '${l.countryRegionName('JP')} · ';
            final text = tester.widget<Text>(
              find.descendant(
                of: find.byKey(ValueKey(index + 1)),
                matching: find.text('$prefix$label'),
              ),
            );
            final span = text.textSpan! as TextSpan;
            expect(span.text, prefix);
            expect(text.style!.color, palette.mutedForeground);
            expect(span.children!.single.style!.color, color);
            if (PingDelayConstants.isSuccessful(delay)) {
              for (final background in [
                palette.card,
                palette.selectedSurface,
              ]) {
                final foregroundLuminance = color.computeLuminance() + 0.05;
                final backgroundLuminance =
                    background.computeLuminance() + 0.05;
                final contrast = foregroundLuminance > backgroundLuminance
                    ? foregroundLuminance / backgroundLuminance
                    : backgroundLuminance / foregroundLuminance;
                expect(contrast, greaterThanOrEqualTo(4.5));
              }
            }
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final width in [427.0, 1160.0]) {
    for (final grouping in ServerGrouping.values) {
      testWidgets(
        'group test can be cancelled without locking menus: $grouping at $width',
        (tester) async {
          controller.groupBy(grouping);
          controller.sources = [
            SubscriptionData(
              id: 4,
              name: 'Source',
              url: 'https://example.test/sub',
              timestamp: DateTime(2026),
            ),
          ];
          controller.servers = [_server(1, 'JP').copyWith(subId: 4)];
          await pumpBrowser(tester, width, groupPage: true);
          final l = AppLocalizations.of(
            tester.element(find.byType(ServerGroupView)),
          )!;
          final group = controller.groups(l).single;
          controller.emit(
            controller.state.copyWith(
              testingServerIds: {1},
              testingServerGroupId: group.id,
            ),
          );
          AppEventBus.instance.updatePinging(true);
          expect(controller.testingGroup(group), isTrue);
          await tester.pump();
          await tester.pump();

          for (final menu in [
            find.byType(ServerMenu),
            find.byType(SourceMenu),
          ]) {
            for (final element in menu.evaluate()) {
              final button = tester.widget<IconButton>(
                find.descendant(
                  of: find.byWidget(element.widget),
                  matching: find.byType(IconButton),
                ),
              );
              expect(button.onPressed, isNotNull);
              expect(button.icon, isA<Icon>());
              expect((button.icon as Icon).icon, LucideIcons.ellipsis);
            }
          }
          expect(find.byType(ButtonProgressIndicator), findsOneWidget);
          await tester.tap(
            find.widgetWithText(OutlinedButton, l.prototypeCancel),
          );
          await tester.pump();
          await tester.pump();
          expect(controller.state.cancellingServerTest, isTrue);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, l.prototypePleaseWait),
                )
                .onPressed,
            isNull,
          );

          controller.emit(
            controller.state.copyWith(
              testingServerIds: {},
              testingServerGroupId: null,
              cancellingServerTest: false,
            ),
          );
          AppEventBus.instance.updatePinging(false);
          await tester.pumpAndSettle();
          expect(
            find.widgetWithText(OutlinedButton, l.prototypeTestServers),
            findsOneWidget,
          );
          expect(find.byType(ButtonProgressIndicator), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final (width, groupPage) in [
    (427.0, false),
    (427.0, true),
    (1160.0, false),
    (1160.0, true),
  ]) {
    testWidgets('automatic probing shows loading ($width, group: $groupPage)', (
      tester,
    ) async {
      late Completer<void> started;
      late Completer<void> release;
      late PingService ping;
      final row = await tester.runAsync(() async {
        started = Completer<void>();
        release = Completer<void>();
        ping = PingService.forTesting(
          database: db,
          runBatch: (_, _) async {
            started.complete();
            await release.future;
            return const [PingBatchResult(true, 20, '', countryCode: 'JP')];
          },
        );
        final id = await db.coreConfigDao.insertRow(
          outboundCompanion({'tag': 'Imported', 'protocol': 'socks'}),
        );
        return db.coreConfigDao.searchRow(id);
      });
      await controller.close();
      controller = _Controller(
        database: db,
        coordinator: coordinator,
        ping: ping,
      )..servers = [row!];
      await pumpBrowser(tester, width, groupPage: groupPage);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      try {
        await tester.runAsync(() async {
          ping.schedulePingConfigIds([row.id]);
          await started.future.timeout(const Duration(seconds: 5));
        });
        await tester.pump();
        await tester.pump();
        expect(ping.isPinging, isTrue);
        expect(AppEventBus.instance.state.pinging, isTrue);
        expect(controller.testingIds, isEmpty);
        expect(
          find.byType(ButtonProgressIndicator),
          width > AppLayout.mobileBreakpoint && !groupPage
              ? findsNWidgets(2)
              : findsOneWidget,
        );
        if (groupPage || width > AppLayout.mobileBreakpoint) {
          expect(
            tester
                .widget<IconButton>(
                  find.descendant(
                    of: find.byType(ServerMenu),
                    matching: find.byType(IconButton),
                  ),
                )
                .onPressed,
            isNotNull,
          );
          await tester.tap(
            find.widgetWithText(OutlinedButton, l.prototypeTestServers),
          );
          await tester.pump();
          expect(find.text(l.serverTestInProgress), findsOneWidget);
          expect(controller.testingIds, isEmpty);
        }
      } finally {
        await tester.runAsync(() async {
          release.complete();
          // Wait for the scheduled task's database write and event update.
          await ping.pingConfigIds([row.id]);
        });
      }
      await tester.pumpAndSettle();
      expect(find.byType(ButtonProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retesting from an open node menu shows the wait toast', (
    tester,
  ) async {
    controller.servers = [_server(1, 'JP')];
    await pumpBrowser(tester, 427, groupPage: true, locale: const Locale('zh'));
    final l = AppLocalizations.of(
      tester.element(find.byType(ServerGroupView)),
    )!;
    controller.emit(controller.state.copyWith(testingServerIds: {1}));
    await tester.pump();
    expect(controller.serverBusy(controller.servers.single), isFalse);
    expect(find.byType(ButtonProgressIndicator), findsNothing);

    await tester.tap(find.byTooltip('${l.prototypeMoreActions}: Node 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.prototypeTestAgain));
    await tester.pumpAndSettle();
    expect(find.byType(ShadToast), findsOneWidget);
    expect(find.text('测速中，请等待测速完成后再试。'), findsOneWidget);
    expect(controller.testingIds, {1});
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('en'), Locale('ru'), Locale('fa')]) {
    testWidgets(
      'desktop tabs use equal-width cards and independent scrolls: $locale',
      (tester) async {
        await pumpBrowser(tester, 1160, locale: locale);
        final browser = find.byType(ServerBrowser);
        final group = find.byType(ServerGroupView);
        const columnWidth = (1160 - 225 - 56 - 16) / 2;
        expect(group, findsOneWidget);
        expect(tester.getSize(group).width, closeTo(columnWidth, 1));
        expect(
          find.descendant(
            of: browser,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          ),
          findsNWidgets(2),
        );
        expect(find.byType(ServerNodeRow), findsNWidgets(3));
        expect(
          find.byType(TabBar),
          findsNothing,
        ); // Desktop tabs live in AppBar.
        expect(find.byType(VerticalDivider), findsNothing);
        expect(find.byType(PopupMenuButton<ServerAction>), findsNothing);

        controller.groupBy(ServerGrouping.location);
        await tester.pumpAndSettle();
        expect(group, findsOneWidget);
        expect(tester.getSize(group).width, closeTo(columnWidth, 1));
        expect(find.byType(ServerNodeRow), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'compact desktop stacks cards and browsing updates the shared detail',
    (tester) async {
      controller.groupBy(ServerGrouping.location);
      await pumpBrowser(tester, 900);
      final group = find.byType(ServerGroupView);
      expect(tester.getSize(group).width, closeTo(900 - 190 - 56, 1));
      final l = AppLocalizations.of(
        tester.element(find.byType(ServerBrowser)),
      )!;
      await tester.tap(find.text(l.countryRegionName('SG')));
      await tester.pumpAndSettle();
      expect(controller.browsedOnMobile, isFalse);
      expect(tester.widget<ServerGroupView>(group).group.country, 'SG');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile retains its tabs and separate group navigation', (
    tester,
  ) async {
    await pumpBrowser(tester, 427);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.byType(ServerGroupView), findsNothing);
    final l = AppLocalizations.of(tester.element(find.byType(ServerBrowser)))!;
    expect(controller.grouping, ServerGrouping.subscription);
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.tabs.map((tab) => (tab as Tab).text), [
      l.prototypeBySubscription,
      l.prototypeByNodeLocation,
    ]);
    expect(
      DefaultTabController.of(tester.element(find.byType(TabBar))).index,
      0,
    );
    await tester.tap(find.widgetWithText(Tab, l.prototypeByNodeLocation));
    await tester.pumpAndSettle();
    expect(controller.grouping, ServerGrouping.location);
    await tester.tap(find.text(l.countryRegionName('SG')));
    await tester.pumpAndSettle();
    expect(controller.browsedOnMobile, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final width in [427.0, 900.0, 1160.0]) {
    testWidgets('node lists build lazily and scroll independently at $width', (
      tester,
    ) async {
      final mobile = width <= AppLayout.mobileBreakpoint;
      controller.groupBy(ServerGrouping.location);
      controller.servers = [
        for (var id = 1; id <= 200; id++) _server(id, 'JP'),
        for (final (index, country) in [
          'AR',
          'AT',
          'AU',
          'BE',
          'BR',
          'CA',
          'CH',
          'DE',
          'DK',
          'ES',
          'FI',
          'FR',
          'GB',
          'HK',
          'IE',
          'IN',
          'IT',
          'KR',
          'NL',
          'SG',
        ].indexed)
          _server(201 + index, country),
      ];
      await pumpBrowser(tester, width, groupPage: mobile);
      final group = find.byType(ServerGroupView);
      final rows = find.descendant(
        of: group,
        matching: find.byType(ServerNodeRow),
      );
      final groupScroll = find.descendant(
        of: group,
        matching: find.byType(Scrollable),
      );
      final list = tester.widget<ListView>(
        find.descendant(of: group, matching: find.byType(ListView)),
      );
      expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
      expect(list.shrinkWrap, isFalse);
      expect(rows.evaluate().length, inInclusiveRange(1, 25));
      expect(find.byKey(const ValueKey(200)), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey(200)),
        1000,
        scrollable: groupScroll,
        maxScrolls: 40,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey(200)), findsOneWidget);
      expect(rows.evaluate().length, lessThan(25));
      final last = tester.widget<ServerNodeRow>(
        find.byKey(const ValueKey(200)),
      );
      expect(last.showDivider, isFalse);
      if (!mobile) {
        expect(scroll.offset, 0);
        final position = tester.state<ScrollableState>(groupScroll).position;
        final offset = position.pixels;
        expect(offset, greaterThan(0));
        scroll.jumpTo(200);
        await tester.pumpAndSettle();
        expect(scroll.offset, 200);
        expect(position.pixels, offset);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty server browser replaces browsing controls with actions', (
    tester,
  ) async {
    controller.servers = [];
    await pumpBrowser(tester, 1160);
    final l = AppLocalizations.of(tester.element(find.byType(ServerBrowser)))!;

    expect(find.byType(PageEmptyState), findsOneWidget);
    final emptyCard = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is ShapeDecoration &&
          (widget.decoration as ShapeDecoration).shape is AppDashedBorder,
    );
    final card = tester.getRect(emptyCard);
    expect(card.top, AppSpacing.desktopPageTop);
    expect(card.left, AppLayout.desktopSidebarWidth + AppSpacing.page);
    expect(
      card.width,
      1160 - AppLayout.desktopSidebarWidth - AppSpacing.page * 2,
    );
    expect(card.height, AppLayout.emptyStateDesktopMinHeight);
    expect(find.text(l.prototypeNoServersYet), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ServerGroupView), findsNothing);
    expect(find.text(l.prototypeAutomaticRecommended), findsNothing);

    await tester.tap(find.text(l.prototypeHowGetServers));
    await tester.pump();
    expect(controller.helpOpened, isTrue);
    await tester.tap(find.text(l.prototypeAddServer));
    await tester.pump();
    expect(controller.addOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop node menu uses the same action dialog and closes without a mutation',
    (tester) async {
      await pumpBrowser(tester, 1160);
      final l = AppLocalizations.of(
        tester.element(find.byType(ServerBrowser)),
      )!;
      await tester.tap(
        find.byTooltip('${l.prototypeMoreActions}: Node 1').first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ServerActionsMenu), findsOneWidget);
      await tester.tap(find.byTooltip(l.prototypeCloseDialog));
      await tester.pumpAndSettle();
      expect(find.byType(ServerActionsMenu), findsNothing);
      expect(controller.servers, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}
