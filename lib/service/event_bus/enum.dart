import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/localizations/locale.dart';
import 'package:onexray/service/localizations/service.dart';

enum ThemeCode {
  system("system"),
  light("light"),
  dark("dark");

  const ThemeCode(this.name);

  final String name;

  @override
  String toString() {
    switch (this) {
      case ThemeCode.system:
        return appLocalizationsNoContext().themePageSystem;
      case ThemeCode.light:
        return appLocalizationsNoContext().themePageLight;
      case ThemeCode.dark:
        return appLocalizationsNoContext().themePageDark;
    }
  }

  static ThemeCode fromString(String? name) {
    if (name == null) {
      return ThemeCode.system;
    }
    final theme = ThemeCode.values.firstWhereOrNull(
      (value) => value.name == name,
    );
    if (theme == null) {
      return ThemeCode.system;
    }
    return theme;
  }

  ThemeMode get themeMode {
    switch (this) {
      case ThemeCode.light:
        return ThemeMode.light;
      case ThemeCode.dark:
        return ThemeMode.dark;
      case ThemeCode.system:
        return ThemeMode.system;
    }
  }
}

enum LanguageCode {
  system("system"),
  en("en"),
  ru("ru"),
  fa("fa"),
  zh("zh"),
  zhHant("zh_Hant");

  const LanguageCode(this.name);

  final String name;

  @override
  String toString() {
    switch (this) {
      case LanguageCode.system:
        return appLocalizationsNoContext().prototypeFollowSystem;
      case LanguageCode.en:
        return appLocalizationsNoContext().prototypeEnglish;
      case LanguageCode.ru:
        return appLocalizationsNoContext().prototypeRussian;
      case LanguageCode.fa:
        return appLocalizationsNoContext().prototypePersian;
      case LanguageCode.zh:
        return appLocalizationsNoContext().prototypeSimplifiedChinese;
      case LanguageCode.zhHant:
        return appLocalizationsNoContext().prototypeTraditionalChinese;
    }
  }

  static LanguageCode fromString(String? name) {
    if (name == null) {
      return LanguageCode.zh;
    }
    final value = LanguageCode.values.firstWhereOrNull(
      (value) => value.name == name,
    );
    if (value != null) {
      return value;
    }
    return LanguageCode.zh;
  }

  Locale get locale {
    Locale current;
    switch (this) {
      case LanguageCode.system:
        final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
        current = deviceLocale;
        break;
      default:
        current = switch (this) {
          LanguageCode.zh => AppLocalePolicy.simplifiedChinese,
          LanguageCode.zhHant => AppLocalePolicy.traditionalChinese,
          _ => Locale(name),
        };
        break;
    }
    return AppLocalePolicy.resolve(
      current,
      AppLocalePolicy.normalizeSupportedLocales(
        AppLocalizations.supportedLocales,
      ),
    );
  }

  TextDirection get textDirection =>
      locale.languageCode == "fa" ? TextDirection.rtl : TextDirection.ltr;
}
