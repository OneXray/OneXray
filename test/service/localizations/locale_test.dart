import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/localizations/locale.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const generatedLocales = <Locale>[
    Locale("en"),
    Locale("zh"),
    Locale.fromSubtags(languageCode: "zh", scriptCode: "Hant"),
  ];
  final supportedLocales = AppLocalePolicy.normalizeSupportedLocales(
    generatedLocales,
  );

  test("normalizes generated Chinese locales to explicit scripts", () {
    expect(supportedLocales, <Locale>[
      const Locale("en"),
      AppLocalePolicy.simplifiedChinese,
      AppLocalePolicy.traditionalChinese,
    ]);
  });

  test("resolves Simplified Chinese to zh-Hans", () {
    expect(
      AppLocalePolicy.resolve(const Locale("zh"), supportedLocales),
      AppLocalePolicy.simplifiedChinese,
    );
    expect(
      AppLocalePolicy.resolve(const Locale("zh", "CN"), supportedLocales),
      AppLocalePolicy.simplifiedChinese,
    );
  });

  test("resolves Traditional Chinese regions to zh-Hant", () {
    for (final countryCode in <String>["TW", "HK", "MO"]) {
      expect(
        AppLocalePolicy.resolve(
          Locale.fromSubtags(languageCode: "zh", countryCode: countryCode),
          supportedLocales,
        ),
        AppLocalePolicy.traditionalChinese,
      );
    }
  });

  test("unsupported or absent system language falls back to English", () {
    final reversedLocales = supportedLocales.reversed;
    expect(
      AppLocalePolicy.resolve(const Locale("ja"), reversedLocales),
      const Locale("en"),
    );
    expect(AppLocalePolicy.resolve(null, reversedLocales), const Locale("en"));
  });

  test(
    "a new or invalid language preference defaults to Simplified Chinese",
    () {
      expect(LanguageCode.fromString(null), LanguageCode.zh);
      expect(LanguageCode.fromString("unsupported"), LanguageCode.zh);
      expect(LanguageCode.fromString("system"), LanguageCode.system);
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
    expect(LanguageCode.system.locale, AppLocalePolicy.traditionalChinese);
    expect(LanguageCode.system.textDirection, TextDirection.ltr);
  });

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
