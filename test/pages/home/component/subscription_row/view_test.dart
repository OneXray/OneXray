import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/component/subscription_row/view.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    eventBus = AppEventBus();
  });

  tearDown(() => eventBus.close());

  testWidgets('phone subscription row separates toggle and 40px actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var toggled = false;

    await tester.pumpWidget(
      _app(
        eventBus,
        SubscriptionRowView(
          item: _subscriptionItem(),
          pingCallback: () {},
          expandCallback: () {},
          tapCallback: () => toggled = true,
        ),
      ),
    );
    await tester.pump();

    final toggle = find.ancestor(
      of: find.text('Premium Network'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(toggle.first).height, greaterThanOrEqualTo(40));

    final buttons = tester
        .widgetList<ShadIconButton>(find.byType(ShadIconButton))
        .toList();
    expect(buttons, hasLength(2));
    for (final button in buttons) {
      expect(button.width, 40);
      expect(button.height, 40);
    }

    expect(
      tester.getCenter(find.byIcon(LucideIcons.chevronDown)).dx,
      lessThan(tester.getCenter(find.text('Premium Network')).dx),
    );
    await tester.tap(find.text('Premium Network'));
    expect(toggled, isTrue);
  });

  testWidgets('desktop subscription row exposes a 40px labeled ping action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        eventBus,
        SubscriptionRowView(
          item: _subscriptionItem(),
          pingCallback: () {},
          expandCallback: () {},
          tapCallback: () {},
        ),
      ),
    );
    await tester.pump();

    final pingButton = tester.widget<ShadButton>(
      find.widgetWithText(ShadButton, 'Ping'),
    );
    final menuButton = tester.widget<ShadIconButton>(
      find.byType(ShadIconButton),
    );
    expect(pingButton.height, 40);
    expect(menuButton.width, 40);
    expect(menuButton.height, 40);
  });
}

SubscriptionItem _subscriptionItem() {
  final data = SubscriptionData(
    id: 2,
    name: 'Premium Network',
    url: 'https://example.com/sub.txt',
    timestamp: DateTime(2026),
    count: 7,
    expanded: true,
  );
  return SubscriptionItem(data, ConfigQueryRowType.subscription)..count = 7;
}

Widget _app(AppEventBus eventBus, Widget child) {
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
    home: BlocProvider.value(
      value: eventBus,
      child: Scaffold(body: child),
    ),
  );
}
