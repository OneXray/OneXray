import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/tun/app_icon/view.dart';
import 'package:onexray/pages/core/tun/installed_app/page.dart';
import 'package:onexray/pages/core/tun/installed_app/params.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('every row resolves its icon through the flow providers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadBlueColorScheme.light(),
            radius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: InstalledAppPage(
          params: InstalledAppParams([
            AndroidAppInfo(name: 'OneXray', packageName: 'net.yuandev.onexray'),
            AndroidAppInfo(name: 'Browser', packageName: 'com.example.browser'),
          ], {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Off Android the bridge has no icon to hand back, so the rows keep the
    // fallback glyph; what matters here is that the icon controller is in scope.
    expect(find.byType(DataListRow), findsNWidgets(2));
    expect(find.byType(AppIconView), findsNWidgets(2));
    expect(find.byIcon(LucideIcons.package), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
