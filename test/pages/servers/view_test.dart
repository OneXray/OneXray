import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/controller.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/menus.dart';
import 'package:onexray/pages/servers/view.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/service/connection/coordinator.dart';

class _Controller extends ServersController {
  _Controller({required super.database, required super.coordinator});

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
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final mobile = width <= AppLayout.mobileBreakpoint;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(Brightness.light, mobile: mobile),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
                    builder: (context, _) =>
                        ServerBrowser(controller: controller, scroll: scroll),
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

  for (final locale in const [Locale('en'), Locale('ru'), Locale('fa')]) {
    testWidgets(
      'desktop shares one scroll surface and responsive cards: $locale',
      (tester) async {
        await pumpBrowser(tester, 1160, locale: locale);
        final browser = find.byType(ServerBrowser);
        final group = find.byType(ServerGroupView);
        expect(group, findsOneWidget);
        expect(
          tester.getSize(group).width,
          closeTo((1160 - 225 - 56 - 16) * .59, 1),
        );
        expect(
          find.descendant(
            of: browser,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          ),
          findsOneWidget,
        );
        expect(find.byType(ServerNodeRow), findsNWidgets(2));
        expect(
          find.byType(TabBar),
          findsNothing,
        ); // Desktop tabs live in AppBar.
        expect(find.byType(VerticalDivider), findsNothing);
        expect(find.byType(PopupMenuButton<ServerAction>), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'compact desktop stacks cards and browsing updates the shared detail',
    (tester) async {
      await pumpBrowser(tester, 900);
      final group = find.byType(ServerGroupView);
      expect(tester.getSize(group).width, closeTo(900 - 190 - 56, 1));
      final l = AppLocalizations.of(
        tester.element(find.byType(ServerBrowser)),
      )!;
      await tester.tap(find.text(l.prototypeSingapore));
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
    await tester.tap(find.text(l.prototypeSingapore));
    await tester.pumpAndSettle();
    expect(controller.browsedOnMobile, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty server browser replaces browsing controls with actions', (
    tester,
  ) async {
    controller.servers = [];
    await pumpBrowser(tester, 1160);
    final l = AppLocalizations.of(tester.element(find.byType(ServerBrowser)))!;

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
