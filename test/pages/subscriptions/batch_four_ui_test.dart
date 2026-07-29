import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/subscriptions/list/view.dart';
import 'package:onexray/pages/subscriptions/widget/form_view.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/date_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    eventBus = AppEventBus();
  });

  tearDown(() async {
    await eventBus.close();
  });

  Widget app(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, appChild) => ShadTheme(
        data: ShadThemeData(
          colorScheme: const ShadBlueColorScheme.light(),
          radius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: appChild ?? const SizedBox.shrink(),
      ),
      home: Scaffold(body: SafeArea(child: child)),
    );
  }

  testWidgets('subscription form keeps the approved fields on desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    addTearDown(nameController.dispose);
    addTearDown(urlController.dispose);

    await tester.pumpWidget(
      app(
        SubscriptionFormView(
          supportText: 'Supported formats',
          nameLabel: 'Name',
          nameController: nameController,
          urlLabel: 'URL',
          urlController: urlController,
          urlHint: 'https://example.com/sub.txt',
          urlHelper: 'HTTPS only',
          autoUpdateTitle: 'Auto Update',
          autoUpdateValue: 'Enabled · Three days',
          onOpenAutoUpdate: () {},
        ),
      ),
    );

    expect(find.text('Supported formats'), findsOneWidget);
    expect(find.text('Name'), findsWidgets);
    expect(find.text('URL'), findsWidgets);
    expect(find.text('HTTPS only'), findsOneWidget);
    expect(find.text('Auto Update'), findsOneWidget);
    expect(find.text('Enabled · Three days'), findsOneWidget);
    final autoUpdateValueAlign = tester.widget<Align>(
      find.byKey(const ValueKey('subscriptionAutoUpdateValue')),
    );
    expect(autoUpdateValueAlign.alignment, AlignmentDirectional.centerEnd);
    expect(find.byType(ShadInput), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'subscription form remains scrollable without overflow on phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final nameController = TextEditingController();
      final urlController = TextEditingController();
      addTearDown(nameController.dispose);
      addTearDown(urlController.dispose);

      await tester.pumpWidget(
        app(
          SubscriptionFormView(
            supportText: 'Supported formats',
            nameLabel: 'Name',
            nameController: nameController,
            urlLabel: 'URL',
            urlController: urlController,
            urlHelper: 'HTTPS only',
            autoUpdateTitle: 'Auto Update',
            onOpenAutoUpdate: () {},
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('subscription list card exposes count and open action', (
    tester,
  ) async {
    final subscription = SubscriptionData(
      id: 2,
      name: 'Premium Network',
      url: 'https://example.com/sub.txt',
      timestamp: DateTime(2026),
      count: 7,
      expanded: true,
    );
    final item = SubscriptionItem(subscription, ConfigQueryRowType.subscription)
      ..count = 7;
    var opened = false;

    await tester.pumpWidget(
      app(
        SubscriptionListView(
          items: [item],
          emptyMessage: 'No subscriptions',
          addLabel: 'Add',
          pingLabel: 'Ping',
          pinging: false,
          onAdd: () {},
          onOpen: (_) => opened = true,
          onPing: (_) {},
          onAction: (_, IconMenuId _) {},
        ),
      ),
    );

    expect(find.text('Premium Network'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.byType(DateView), findsOneWidget);
    await tester.tap(find.text('Premium Network'));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('subscription list empty state keeps the add action', (
    tester,
  ) async {
    var added = false;
    await tester.pumpWidget(
      app(
        SubscriptionListView(
          items: const [],
          emptyMessage: 'No subscriptions',
          addLabel: 'Add',
          pingLabel: 'Ping',
          pinging: false,
          onAdd: () => added = true,
          onOpen: (_) {},
          onPing: (_) {},
          onAction: (_, IconMenuId _) {},
        ),
      ),
    );

    expect(find.text('No subscriptions'), findsOneWidget);
    await tester.tap(find.text('Add'));
    expect(added, isTrue);
  });

  testWidgets('subscription list empty state disables add while downloading', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        SubscriptionListView(
          items: const [],
          emptyMessage: 'No subscriptions',
          addLabel: 'Add',
          pingLabel: 'Ping',
          pinging: false,
          onAdd: null,
          onOpen: (_) {},
          onPing: (_) {},
          onAction: (_, IconMenuId _) {},
        ),
      ),
    );

    expect(find.text('No subscriptions'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
  });
}
