import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/full_config/controller.dart';
import 'package:onexray/pages/core/xray/full_config/page.dart';
import 'package:onexray/pages/core/xray/full_config/params.dart';
import 'package:onexray/pages/widget/settings_page.dart';
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

    final nextButton = find.descendant(
      of: navigation,
      matching: find.byIcon(LucideIcons.chevronRight),
    );
    expect(nextButton, findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('DNS').first);
    await tester.pump();

    expect(find.text('Hosts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
