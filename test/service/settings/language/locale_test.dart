import 'dart:ffi';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/shared/event_bus/enum.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:onexray/service/settings/language/service.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final isLinuxArm64 = Platform.isLinux && Abi.current() == Abi.linuxArm64;
  const generatedLocales = <Locale>[
    Locale("en"),
    Locale("zh"),
    Locale.fromSubtags(languageCode: "zh", scriptCode: "Hant"),
  ];
  final supportedLocales = AppLocalePolicy.normalizeSupportedLocales(
    generatedLocales,
  );

  test("Linux ARM64 resolves CJK locales to English", () {
    expect(
      AppLocalePolicy.resolve(const Locale("zh", "CN"), supportedLocales),
      AppLocalePolicy.english,
    );
  }, skip: !isLinuxArm64);

  test("Linux ARM64 fallback precedes exact and regional CJK matching", () {
    final locales = [
      ...supportedLocales,
      const Locale("ja"),
      const Locale("ko"),
    ];
    for (final locale in const [
      Locale("zh"),
      Locale("zh", "CN"),
      Locale("zh", "SG"),
      Locale("zh", "TW"),
      Locale("zh", "HK"),
      Locale("zh", "MO"),
      AppLocalePolicy.simplifiedChinese,
      AppLocalePolicy.traditionalChinese,
      Locale("ja"),
      Locale("ja", "JP"),
      Locale("ko"),
      Locale("ko", "KR"),
    ]) {
      expect(
        AppLocalePolicy.resolve(locale, locales, abi: Abi.linuxArm64),
        AppLocalePolicy.english,
        reason: locale.toLanguageTag(),
      );
    }
  });

  test("Linux ARM64 preserves supported non-CJK locales", () {
    const locales = [Locale("en"), Locale("ru"), Locale("fa")];
    for (final locale in locales) {
      expect(
        AppLocalePolicy.resolve(locale, locales, abi: Abi.linuxArm64),
        locale,
      );
    }
  });

  test("other platforms and Linux x64 retain supported CJK locales", () {
    const locales = [
      AppLocalePolicy.simplifiedChinese,
      AppLocalePolicy.traditionalChinese,
      Locale("ja"),
      Locale("ko"),
    ];
    for (final abi in [
      Abi.linuxX64,
      Abi.androidArm64,
      Abi.iosArm64,
      Abi.macosArm64,
      Abi.windowsArm64,
    ]) {
      for (final locale in locales) {
        expect(
          AppLocalePolicy.resolve(locale, locales, abi: abi),
          locale,
          reason: '$abi: ${locale.toLanguageTag()}',
        );
      }
    }
  });

  test("normalizes generated Chinese locales to explicit scripts", () {
    expect(supportedLocales, <Locale>[
      const Locale("en"),
      AppLocalePolicy.simplifiedChinese,
      AppLocalePolicy.traditionalChinese,
    ]);
  });

  test("resolves Simplified Chinese to zh-Hans", () {
    expect(
      AppLocalePolicy.resolve(
        const Locale("zh"),
        supportedLocales,
        abi: Abi.linuxX64,
      ),
      AppLocalePolicy.simplifiedChinese,
    );
    expect(
      AppLocalePolicy.resolve(
        const Locale("zh", "CN"),
        supportedLocales,
        abi: Abi.linuxX64,
      ),
      AppLocalePolicy.simplifiedChinese,
    );
  });

  test("resolves Traditional Chinese regions to zh-Hant", () {
    for (final countryCode in <String>["TW", "HK", "MO"]) {
      expect(
        AppLocalePolicy.resolve(
          Locale.fromSubtags(languageCode: "zh", countryCode: countryCode),
          supportedLocales,
          abi: Abi.linuxX64,
        ),
        AppLocalePolicy.traditionalChinese,
      );
    }
  });

  test("unsupported or absent system language falls back to English", () {
    final reversedLocales = supportedLocales.reversed;
    expect(
      AppLocalePolicy.resolve(
        const Locale("ja"),
        reversedLocales,
        abi: Abi.linuxX64,
      ),
      const Locale("en"),
    );
    expect(AppLocalePolicy.resolve(null, reversedLocales), const Locale("en"));
  });

  test("new or invalid appearance preferences follow the system", () {
    for (final value in [null, "unsupported", "system"]) {
      expect(LanguageCode.fromString(value).name, LanguageCode.system.name);
      expect(ThemeCode.fromString(value).name, ThemeCode.system.name);
    }
    for (final language in LanguageCode.values) {
      expect(LanguageCode.fromString(language.name), language);
    }
    for (final theme in ThemeCode.values) {
      expect(ThemeCode.fromString(theme.name), theme);
    }
  });

  test(
    "startup uses English on an English system without overwriting preferences",
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(binding.platformDispatcher.clearLocaleTestValue);
      binding.platformDispatcher.localeTestValue = const Locale("en", "US");
      final bus = AppEventBus();
      addTearDown(bus.close);

      await bus.asyncInitTheme();

      expect(appLocalizationsNoContext().localeName, "en");
      expect(bus.state.languageCode, LanguageCode.system);
      expect(bus.state.themeCode.themeMode, ThemeMode.system);
      expect(await PreferencesKey().readLanguageCode(), isNull);
      expect(await PreferencesKey().readThemeCode(), isNull);

      await bus.updateLanguageCode(LanguageCode.zh);
      await bus.updateThemeCode(ThemeCode.dark);
      await bus.asyncInitTheme();
      expect(bus.state.languageCode, LanguageCode.zh);
      expect(bus.state.themeCode.themeMode, ThemeMode.dark);
      expect(
        appLocalizationsNoContext().localeName,
        isLinuxArm64 ? "en" : "zh",
      );

      await bus.updateLanguageCode(LanguageCode.system);
      await bus.updateThemeCode(ThemeCode.system);
      binding.platformDispatcher.localeTestValue = const Locale("fa", "IR");
      expect(appLocalizationsNoContext().localeName, "fa");
      expect(bus.state.themeCode.themeMode, ThemeMode.system);
    },
  );

  test("system direction follows the resolved supported language", () {
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);
    binding.platformDispatcher.localeTestValue = const Locale("ar");
    expect(LanguageCode.system.locale, const Locale("en"));
    expect(LanguageCode.system.textDirection, TextDirection.ltr);
    binding.platformDispatcher.localeTestValue = const Locale("fa", "IR");
    expect(LanguageCode.system.locale, const Locale("fa"));
    expect(LanguageCode.system.textDirection, TextDirection.rtl);
    binding.platformDispatcher.localeTestValue = const Locale("zh", "TW");
    expect(
      LanguageCode.system.locale,
      isLinuxArm64
          ? AppLocalePolicy.english
          : AppLocalePolicy.traditionalChinese,
    );
    expect(LanguageCode.system.textDirection, TextDirection.ltr);
  });

  testWidgets(
    "UI and background locales agree without rewriting language choices",
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      addTearDown(binding.platformDispatcher.clearLocaleTestValue);
      addTearDown(binding.platformDispatcher.clearLocalesTestValue);
      binding.platformDispatcher.localeTestValue = const Locale("zh", "TW");
      binding.platformDispatcher.localesTestValue = const [Locale("zh", "TW")];
      final bus = AppEventBus();
      addTearDown(bus.close);
      const probe = ValueKey('locale-probe');

      for (final (language, requested) in const [
        (LanguageCode.system, AppLocalePolicy.traditionalChinese),
        (LanguageCode.zh, AppLocalePolicy.simplifiedChinese),
        (LanguageCode.zhHant, AppLocalePolicy.traditionalChinese),
        (LanguageCode.en, AppLocalePolicy.english),
        (LanguageCode.ru, Locale("ru")),
        (LanguageCode.fa, Locale("fa")),
      ]) {
        await bus.updateLanguageCode(language);
        final expected = isLinuxArm64 && requested.languageCode == "zh"
            ? AppLocalePolicy.english
            : requested;
        await tester.pumpWidget(
          MaterialApp(
            locale: language == LanguageCode.system ? null : language.locale,
            localizationsDelegates: AppLocalePolicy.localizationsDelegates,
            supportedLocales: AppLocalePolicy.normalizeSupportedLocales(
              AppLocalizations.supportedLocales,
            ),
            localeResolutionCallback: AppLocalePolicy.resolve,
            home: const SizedBox(key: probe),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byKey(probe));
        expect(Localizations.localeOf(context), expected);
        expect(language.locale, expected);
        expect(
          AppLocalizations.of(context)!.localeName,
          appLocalizationsNoContext().localeName,
        );
        expect(bus.state.languageCode, language);
        expect(await PreferencesKey().readLanguageCode(), language.name);
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    "approved latency labels accept measured and unavailable values",
    () async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l = await AppLocalizations.delegate.load(locale);
        for (final latency in <Object>[42, '—']) {
          expect(
            l.prototypeCurrentServerLatency('Tokyo', latency),
            allOf(contains('Tokyo'), contains('$latency')),
          );
          expect(
            l.prototypeGroupAvailability(1, 3, latency),
            allOf(contains('1'), contains('3'), contains('$latency')),
          );
        }
      }
    },
  );
}
