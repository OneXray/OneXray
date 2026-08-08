import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/localizations/locale.dart';

void main() {
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

  test("falls back to the first locale for unsupported languages", () {
    expect(
      AppLocalePolicy.resolve(const Locale("ja"), supportedLocales),
      const Locale("en"),
    );
  });
}
