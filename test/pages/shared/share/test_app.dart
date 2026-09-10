import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/settings/language/locale.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ShareTestApp extends StatelessWidget {
  const ShareTestApp({super.key, required this.child, this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    locale: const Locale('en'),
    theme: AppTheme.light,
    localizationsDelegates: AppLocalePolicy.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (_, child) => ShadTheme(
      data: AppTheme.shad(Brightness.light),
      child: ShadToaster(child: child ?? const SizedBox.shrink()),
    ),
    home: Scaffold(body: child),
  );
}

class FakeSharePlatform extends SharePlatform {
  FakeSharePlatform(this.send);

  final Future<ShareResult> Function(ShareParams) send;

  @override
  Future<ShareResult> share(ShareParams params) => send(params);
}
