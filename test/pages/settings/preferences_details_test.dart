import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/app_icon/controller.dart';
import 'package:onexray/pages/settings/app_icon/page.dart';
import 'package:onexray/pages/settings/language/controller.dart';
import 'package:onexray/pages/settings/language/page.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  Widget app(Locale locale, Widget child) => MaterialApp(
    theme: AppTheme.light,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => ShadTheme(
      data: ShadThemeData(colorScheme: const ShadBlueColorScheme.light()),
      child: child ?? const SizedBox.shrink(),
    ),
    home: Scaffold(body: child),
  );

  test('language selection stays a draft until save', () async {
    final bus = AppEventBus();
    final initial = bus.state.languageCode;
    final controller = LanguageController();
    controller.updateLanguageCode(LanguageCode.fa);
    expect(controller.state.languageCode, LanguageCode.fa);
    expect(bus.state.languageCode, initial);
    await controller.close();
    expect(bus.state.languageCode, initial);
    await bus.close();
  });

  for (final locale in const [
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('en'),
    Locale('ru'),
    Locale('fa'),
  ]) {
    testWidgets(
      'settings language and icon choices fit ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        LanguageCode? language;
        await tester.pumpWidget(
          app(
            locale,
            LanguageChoiceView(
              selected: LanguageCode.zh,
              onSelected: (value) => language = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final label in ['简体中文', '繁體中文', 'English', 'Русский', 'فارسی']) {
          expect(find.text(label), findsWidgets);
        }
        await tester.tap(find.text('فارسی').first);
        expect(language, LanguageCode.fa);
        expect(tester.takeException(), isNull);

        AppIcon? icon;
        await tester.pumpWidget(
          app(
            locale,
            Builder(
              builder: (context) => AppIconChoiceView(
                selected: AppIcon.primary,
                useDockIconAssets: false,
                description: AppLocalizations.of(context)!
                    .prototypeHomeScreenIconHint,
                onSelected: (value) => icon = value,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AppIconChoiceView)),
        )!;
        expect(find.text(l10n.prototypeHomeScreenPreview), findsOneWidget);
        for (final option in AppIcon.values) {
          expect(find.text(appIconLabel(l10n, option)), findsOneWidget);
        }
        final icons = find.byType(Image);
        expect(tester.getSize(icons.first), const Size(100, 100));
        expect(tester.getSize(icons.at(1)), const Size(62, 62));
        expect(
          tester.getTopLeft(icons.at(1)).dy,
          tester.getTopLeft(icons.at(3)).dy,
        );
        expect(
          tester.getTopLeft(icons.at(4)).dy,
          greaterThan(tester.getTopLeft(icons.at(1)).dy),
        );
        await tester.tap(find.text(l10n.prototypeIconBlack));
        expect(icon, AppIcon.black);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
