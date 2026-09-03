import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/servers/menus.dart';
import 'package:onexray/pages/servers/sources.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connection/coordinator.dart';

const _open = Key('open-sources');
final _source = SubscriptionData(
  id: 7,
  name: 'Example subscription',
  url: 'https://example.test/subscription',
  timestamp: DateTime(2026, 9, 1, 9, 42),
  count: 99,
  expanded: true,
);

CoreConfigData _server(int id, {int source = 0}) => CoreConfigData(
  id: id,
  name: 'Server $id',
  type: 'outbound',
  tags: '',
  delay: 20,
  subId: source,
  favorite: false,
);

class _Controller extends ServersController {
  _Controller({required super.database, required super.coordinator});

  final actions = <SourceAction>[];

  @override
  Future<void> sourceAction(
    BuildContext context,
    SubscriptionData source,
    SourceAction action,
  ) async {
    expect(context.mounted, isTrue);
    expect(source.id, _source.id);
    actions.add(action);
  }
}

String _label(AppLocalizations l, SourceAction action) => switch (action) {
  SourceAction.update => l.prototypeCheckForUpdates,
  SourceAction.test => l.prototypeTestServers,
  SourceAction.edit => l.prototypeEditSubscription,
  SourceAction.share => l.prototypeShareSubscription,
  SourceAction.delete => l.prototypeDelete,
};

void main() {
  late AppDatabase db;
  late ConnectionCoordinator coordinator;
  late _Controller controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    coordinator = ConnectionCoordinator(database: db);
    controller = _Controller(database: db, coordinator: coordinator);
  });

  tearDown(() async {
    controller.dispose();
    coordinator.dispose();
    await db.close();
  });

  Future<void> pumpSources(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(427, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.material(Brightness.light, mobile: true),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: _open,
              onPressed: () => controller.openSources(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
  }

  testWidgets('local servers appear without a subscription or source actions', (
    tester,
  ) async {
    controller.servers = List.generate(4, (index) => _server(index + 1));
    await pumpSources(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(ServerSourcesDialog)),
    )!;
    expect(find.text(l.prototypeManualAdditions), findsOneWidget);
    expect(
      find.text('${l.prototypeServerCount(4)} · ${l.prototypeLocalOnly}'),
      findsOneWidget,
    );
    expect(find.text(l.prototypeStoredOnThisDevice), findsOneWidget);
    expect(find.text(l.prototypeNoServersYet), findsNothing);
    expect(find.byTooltip(l.prototypeCheckForUpdates), findsNothing);
    await tester.tap(find.byTooltip(l.prototypeCloseDialog));
    await tester.pumpAndSettle();
    expect(find.byType(ServerSourcesDialog), findsNothing);
    expect(controller.actions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu replaces sources and closing ends the flow', (
    tester,
  ) async {
    controller.sources = [_source];
    controller.servers = [_server(1, source: 7), _server(2, source: 7)];
    controller.sourceErrors[7] = 'Stored update failure';
    await pumpSources(tester);
    final context = tester.element(find.byType(ServerSourcesDialog));
    final l = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    expect(find.text('Stored update failure'), findsOneWidget);
    expect(find.text(l.prototypeUpdated), findsNothing);
    expect(
      find.textContaining(material.formatMediumDate(_source.timestamp)),
      findsOneWidget,
    );
    await tester.tap(
      find.byTooltip('${l.prototypeMoreActions}: ${_source.name}'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ServerSourcesDialog), findsNothing);
    expect(find.byType(SourceActionsMenu), findsOneWidget);
    expect(find.text(l.prototypeServerCount(2)), findsOneWidget);
    expect(find.text(l.prototypeServerCount(99)), findsNothing);
    await tester.tap(find.byTooltip(l.prototypeCloseDialog));
    await tester.pumpAndSettle();
    expect(find.byType(ServerSourcesDialog), findsNothing);
    expect(find.byType(SourceActionsMenu), findsNothing);
    expect(controller.actions, isEmpty);

    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    expect(find.byType(ServerSourcesDialog), findsOneWidget);
    expect(find.text('Stored update failure'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all subscription actions dispatch once after the menu closes', (
    tester,
  ) async {
    controller.sources = [_source];
    controller.servers = [_server(1, source: 7)];
    await pumpSources(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(ServerSourcesDialog)),
    )!;
    for (final action in SourceAction.values) {
      if (action != SourceAction.values.first) {
        await tester.tap(find.byKey(_open));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.byTooltip('${l.prototypeMoreActions}: ${_source.name}'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(_label(l, action)));
      await tester.pumpAndSettle();
      expect(controller.actions.last, action);
      expect(find.byType(ServerSourcesDialog), findsNothing);
      expect(find.byType(SourceActionsMenu), findsNothing);
    }
    expect(controller.actions, SourceAction.values);
    expect(tester.takeException(), isNull);
  });
}
