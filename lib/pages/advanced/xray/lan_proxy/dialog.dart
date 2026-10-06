import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/alert.dart';

Future<bool> confirmLanProxyRestart(BuildContext context) {
  if (!context.mounted) return Future.value(false);
  final l = AppLocalizations.of(context)!;
  return ContextAlert.showConfirmDialog(
    context,
    title: l.lanProxyRestartTitle,
    content: l.lanProxyRestartNotice,
    confirmLabel: l.lanProxyRestart,
  );
}
