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
          for (final supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale.languageCode) {
              return supportedLocale;
            }
          }
        }
        return supportedLocales.first;
      },
      builder: (_, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        return Directionality(
          textDirection: state.languageCode.textDirection,
          child: child,
        );
      },
    );
  }
}
