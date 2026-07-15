import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/outbound/page.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    eventBus = AppEventBus();
  });

  tearDown(() async {
    await eventBus.close();
  });

  testWidgets('outbound editor uses five top-level sections on phone', (
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
        home: OutboundUIPage(
          params: OutboundUIParams(
            DBConstants.defaultId,
            OutboundState(),
            const [],
            saveToDb: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SettingSection), findsNWidgets(5));
    expect(find.text('sockopt'), findsOneWidget);
    expect(find.text('mux'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
