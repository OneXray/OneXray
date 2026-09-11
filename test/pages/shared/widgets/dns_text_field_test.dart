import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/widgets/dns_text_field.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/settings/language/locale.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    for (final width in [390.0, 1200.0]) {
      testWidgets('DNS inputs support edits and reset in $locale at $width', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        var value = '1.1.1.1';
        String? changed;
        Widget app() => MaterialApp(
          theme: AppTheme.material(Brightness.light, mobile: width < 600),
          locale: locale,
          localizationsDelegates: AppLocalePolicy.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final l = AppLocalizations.of(context)!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    spacing: 18,
                    children: [
                      DnsTextField(
                        label: l.routingLocalDnsAddress,
                        value: value,
                        onChanged: (text) => changed = text,
                      ),
                      DnsTextField(
                        label: l.prototypeIpv4Dns,
                        value: '8.8.8.8',
                        onChanged: (_) {},
                      ),
                      DnsTextField(
                        label: l.prototypeIpv6Dns,
                        value: '2001:4860:4860::8888',
                        onChanged: (_) {},
                      ),
                      DnsTextField(
                        label: l.prototypeDomain,
                        value: 'dns.google',
                        hint: l.tunnelDnsServerNameHint,
                        onChanged: (_) {},
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        for (final input in tester.widgetList<TextField>(
          find.byType(TextField),
        )) {
          expect(input.textDirection, TextDirection.ltr);
          expect(input.autocorrect, false);
        }
        await tester.enterText(find.byType(TextField).first, '9.9.9.9');
        expect(changed, '9.9.9.9');
        value = '8.8.8.8';
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          value,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
