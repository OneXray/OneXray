import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/outbound/page.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    eventBus = AppEventBus();
  });

  tearDown(() async {
    await eventBus.close();
  });

  testWidgets('outbound editor shows only the shallow form and Raw JSON hint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final outbound = newOutboundMap();
    final stream = outbound['streamSettings'] as Map<String, dynamic>;
    stream
      ..['security'] = 'tls'
      ..remove('realitySettings')
      ..['tlsSettings'] = <String, dynamic>{
        'serverName': 'example.com',
        'alpn': ['h2'],
      };

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
            outbound,
            saveToDb: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SettingSection), findsNWidgets(3));
    expect(
      find.text(
        'The UI supports only common Outbound fields; edit other fields in Raw JSON.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Raw JSON'), findsOneWidget);
    expect(find.text('VLESS'), findsOneWidget);
    expect(find.text('sockopt'), findsNothing);
    expect(find.text('mux'), findsNothing);
    expect(find.text('reverse'), findsNothing);
    expect(find.text('finalmask'), findsNothing);
    expect(find.text('ALPN'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('VLESS'));
    await tester.pumpAndSettle();

    expect(find.text('Hysteria2'), findsOneWidget);
    expect(find.text('HTTP'), findsNothing);
  });
}
