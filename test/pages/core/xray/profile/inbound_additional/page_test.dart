import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/page.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/params.dart';
import 'package:onexray/service/xray/profile/additional_inbound_state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('SOCKS editor shows listener, authentication, and UDP', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        AdditionalInboundPage(
          params: AdditionalInboundParams(InboundSocksState()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SOCKS Inbound'), findsOneWidget);
    expect(find.text('Listener'), findsOneWidget);
    expect(find.text('Authentication'), findsOneWidget);
    expect(find.text('UDP'), findsOneWidget);
    expect(find.text('Target'), findsNothing);
  });

  testWidgets('dokodemo-door editor shows a fixed local listener and target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        AdditionalInboundPage(
          params: AdditionalInboundParams(
            InboundDokodemoDoorState(targetPort: '8888'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('dokodemo-door Inbound'), findsOneWidget);
    expect(find.text('127.0.0.1'), findsWidgets);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Authentication'), findsNothing);
  });
}

Widget _testApp(Widget home) {
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
    home: home,
  );
}
