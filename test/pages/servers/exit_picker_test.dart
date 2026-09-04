import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/pages/routing/widgets.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/exit_picker.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/service/connection/coordinator.dart';
import 'package:onexray/service/xray/outbound/map.dart';

CoreConfigData _server(int id, {int delay = 20}) => CoreConfigData(
  id: id,
  name: 'Server $id',
  type: 'outbound',
  tags: '',
  data: base64Encode(
    utf8.encode(
      encodeSingleOutbound({
        'tag': 'Server $id',
        'protocol': 'vless',
        'streamSettings': {'network': 'xhttp', 'security': 'tls'},
      }),
    ),
  ),
  delay: delay,
  subId: 0,
  countryCode: 'SG',
  favorite: false,
);

void main() {
  late AppDatabase db;
  late ConnectionCoordinator coordinator;
  late ServerExitPickerController controller;
  final l = AppLocalizationsEn();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    coordinator = ConnectionCoordinator(database: db);
    controller =
        ServerExitPickerController(
            const ServerExitPickerParams(selectedId: 2, excludedIds: {1}),
            database: db,
            coordinator: coordinator,
          )
          ..servers = [
            _server(1),
            _server(2),
            _server(3),
            _server(4, delay: PingDelayConstants.error),
          ]
          ..ready = true;
  });

  tearDown(() async {
    controller.dispose();
    coordinator.dispose();
    await db.close();
  });

  test('draft keeps exclusions, real health and search across grouping', () {
    final before = controller.configuration.encode();
    controller.selectDraft(controller.servers.first);
    expect(controller.selectedId, 2);
    expect(
      controller.exitRowDetail(l, controller.servers.first),
      l.prototypeEntryServer,
    );
    controller.selectDraft(controller.servers.last);
    expect(controller.selectedId, 2);
    expect(
      controller.exitRowDetail(l, controller.servers.last),
      l.prototypeTemporarilyUnavailable,
    );
    controller.selectDraft(controller.servers[2]);
    expect(controller.selectedId, 3);
    controller.search.text = 'Server 3';
    controller.groupBy(ServerGrouping.subscription);
    expect(controller.search.text, 'Server 3');
    expect(controller.selectionGroups(l).single.visibleRows.single.id, 3);
    expect(
      controller.exitRowDetail(l, controller.servers[2]),
      '${l.prototypeSingapore} · ${l.prototypeAvailableLatency(20)}',
    );
    expect(controller.configuration.encode(), before);
  });

  Future<void> open(
    WidgetTester tester,
    List<ServerExitChoice?> results, {
    double width = 427,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(
          Brightness.light,
          mobile: width <= AppLayout.mobileBreakpoint,
        ),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                results.add(
                  await Navigator.of(context).push<ServerExitChoice>(
                    MaterialPageRoute(
                      builder: (_) =>
                          ServerExitPickerView(controller: controller),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('flat selection changes only the draft until Done', (
    tester,
  ) async {
    final before = controller.configuration.encode();
    final results = <ServerExitChoice?>[];
    await open(tester, results);
    expect(find.text(l.prototypeVpnFinalExit), findsOneWidget);
    expect(find.text(l.prototypeAddServers), findsNothing);
    expect(find.text(l.prototypeManageSources), findsNothing);
    expect(find.text(l.prototypeFavorites), findsNothing);
    expect(find.text('VLESS | XHTTP | TLS'), findsNWidgets(4));
    await tester.tap(find.text(l.prototypeBySubscription));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Server 3'));
    await tester.pumpAndSettle();
    expect(controller.selectedId, 3);
    expect(results, isEmpty);
    expect(find.byType(ServerExitPickerView), findsOneWidget);
    expect(controller.configuration.encode(), before);
    await tester.tap(find.text(l.prototypeDone));
    await tester.pumpAndSettle();
    expect(results.single?.id, 3);
    expect(find.byType(ServerExitPickerView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop selector keeps a 760 card and a matching footer scope', (
    tester,
  ) async {
    await open(tester, <ServerExitChoice?>[], width: 1160);
    final card = find.byType(RoutingCard);
    expect(tester.getSize(card).width, AppLayout.routingEditorMaxWidth);
    expect(tester.getCenter(card).dx, 580);
    expect(
      tester.getTopLeft(card).dy,
      kToolbarHeight + AppSpacing.desktopPageTop,
    );
    expect(
      tester.widget<PageActionBar>(find.byType(PageActionBar)).maxWidth,
      AppLayout.routingEditorMaxWidth,
    );
    expect(
      find.descendant(of: card, matching: find.byType(IntrinsicWidth)),
      findsOneWidget,
    );
    await tester.tap(find.text(l.prototypeBySubscription));
    await tester.pumpAndSettle();
    expect(controller.grouping, ServerGrouping.subscription);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back cancels; Done can explicitly return no additional exit', (
    tester,
  ) async {
    final results = <ServerExitChoice?>[];
    await open(tester, results);
    await tester.tap(find.text(l.prototypeNoAdditionalExit));
    await tester.pumpAndSettle();
    expect(controller.selectedId, isNull);
    expect(results, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(results, [null]);

    controller.selectedId = controller.params.selectedId;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.prototypeNoAdditionalExit));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.prototypeDone));
    await tester.pumpAndSettle();
    expect(results.last, isA<ServerExitChoice>());
    expect(results.last!.id, isNull);
    expect(tester.takeException(), isNull);
  });
}
