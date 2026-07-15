import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/ui/page.dart';
import 'package:onexray/pages/core/xray/profile/ui/params.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('profile sections render their editors inline', (tester) async {
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
        home: XrayProfileUIPage(
          params: XrayProfileUIParams(DBConstants.defaultId),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TUN Mode'), findsOneWidget);
    expect(find.text('Proxy Mode'), findsOneWidget);

    await tester.tap(find.text('Outbounds').first);
    await tester.pump();

    expect(find.text('Final Outbound'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Edit Outbounds'), findsNothing);
  });
}
