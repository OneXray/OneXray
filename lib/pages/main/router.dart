import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

class GoRouteApp extends StatelessWidget {
  const GoRouteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppEventBus(),
      child: BlocBuilder<AppEventBus, AppEventBusState>(
        builder: (context, state) => _buildApp(context, state),
      ),
    );
  }

  Widget _buildApp(BuildContext context, AppEventBusState state) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "OneXray",
      themeMode: state.themeCode.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: RouterPath.router,
      locale: state.languageCode.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null) {
          final exactLocale = _findSupportedLocale(locale, supportedLocales);
          if (exactLocale != null) {
            return exactLocale;
          }

          final chineseLocale = _resolveChineseLocale(locale, supportedLocales);
          if (chineseLocale != null) {
            return chineseLocale;
          }

          for (final supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode &&
                supportedLocale.scriptCode == locale.scriptCode) {
              return supportedLocale;
            }
          }
          for (final supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return supportedLocales.first;
      },
      builder: (_, child) {
        final routedChild = Directionality(
          textDirection: state.languageCode.textDirection,
          child: child ?? const SizedBox.shrink(),
        );
        return routedChild;
      },
    );
  }

  Locale? _resolveChineseLocale(
    Locale locale,
    Iterable<Locale> supportedLocales,
  ) {
    if (locale.languageCode != "zh") {
      return null;
    }
    final useTraditional =
        locale.scriptCode == "Hant" ||
        locale.countryCode == "TW" ||
        locale.countryCode == "HK" ||
        locale.countryCode == "MO";
    final target = useTraditional
        ? const Locale.fromSubtags(languageCode: "zh", scriptCode: "Hant")
        : const Locale("zh");
    return _findSupportedLocale(target, supportedLocales);
  }

  Locale? _findSupportedLocale(
    Locale locale,
    Iterable<Locale> supportedLocales,
  ) {
    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode &&
          supportedLocale.scriptCode == locale.scriptCode &&
          supportedLocale.countryCode == locale.countryCode) {
        return supportedLocale;
      }
    }
    return null;
  }
}
