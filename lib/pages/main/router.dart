import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/localizations/locale.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    final supportedLocales = AppLocalePolicy.normalizeSupportedLocales(
      AppLocalizations.supportedLocales,
    );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "OneXray",
      themeMode: state.themeCode.themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: RouterPath.router,
      locale: state.languageCode.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: supportedLocales,
      localeResolutionCallback: AppLocalePolicy.resolve,
      builder: (context, child) {
        final routedChild = Directionality(
          textDirection: state.languageCode.textDirection,
          child: child ?? const SizedBox.shrink(),
        );
        final brightness = Theme.of(context).brightness;
        return ShadTheme(
          data: AppTheme.shad(brightness),
          child: ShadToaster(child: routedChild),
        );
      },
    );
  }
}
