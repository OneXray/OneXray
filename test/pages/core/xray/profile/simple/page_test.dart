import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/simple/page.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Simple Profile shows the fixed GeoData update interval', (
    tester,
  ) async {
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
        home: const XrayProfileSimplePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GeoData'), findsOneWidget);
    final intervalFinder = find.widgetWithText(SettingRow, 'Interval');
    final interval = tester.widget<SettingRow>(intervalFinder);
    expect(interval.value, 'One day');
    expect(interval.onTap, isNull);
    expect(find.textContaining('geosite.dat'), findsNothing);
    expect(find.textContaining('geoip.dat'), findsNothing);
  });
}
