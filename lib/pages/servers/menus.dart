import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';

Future<ServerAction?> showServerActionsMenu(
  BuildContext context, {
  required String name,
  required String source,
}) => showAppDialog<ServerAction>(
  context,
  (_) => ServerActionsMenu(name: name, source: source),
);

Future<SourceAction?> showSourceActionsMenu(
  BuildContext context, {
  required String name,
  required int count,
}) => showAppDialog<SourceAction>(
  context,
  (_) => SourceActionsMenu(name: name, count: count),
);

/// Selects an action only; the caller keeps the controller's existing workflow.
class ServerActionsMenu extends StatelessWidget {
  const ServerActionsMenu({
    super.key,
    required this.name,
    required this.source,
  });

  final String name;
  final String source;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AppDialog(
      title: name,
      subtitle: source,
      body: Column(
        children: [
          _menuRow(
            context,
            ServerAction.edit,
            LucideIcons.pencil,
            l.prototypeEditServer,
            hint: l.prototypeEditServerHint,
          ),
          _menuRow(
            context,
            ServerAction.test,
            LucideIcons.refreshCw,
            l.prototypeTestAgain,
            hint: l.prototypeRetestHint,
          ),
          _menuRow(
            context,
            ServerAction.copy,
            LucideIcons.copy,
            l.prototypeSaveAsLocalServer,
            hint: l.prototypeLocalCopyHint,
          ),
          _menuRow(
            context,
            ServerAction.share,
            LucideIcons.share2,
            l.prototypeShareServer,
            hint: l.prototypeShareServerHint,
          ),
          _menuRow(
            context,
            ServerAction.delete,
            LucideIcons.trash2,
            l.prototypeDelete,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

class SourceActionsMenu extends StatelessWidget {
  const SourceActionsMenu({super.key, required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AppDialog(
      title: name,
      subtitle: l.prototypeServerCount(count),
      body: Column(
        children: [
          _menuRow(
            context,
            SourceAction.update,
            LucideIcons.refreshCw,
            l.prototypeCheckForUpdates,
            hint: l.prototypeSourceUpdateHint,
          ),
          _menuRow(
            context,
            SourceAction.test,
            LucideIcons.refreshCw,
            l.prototypeTestServers,
            hint: l.prototypeRetestHint,
          ),
          _menuRow(
            context,
            SourceAction.edit,
            LucideIcons.pencil,
            l.prototypeEditSubscription,
            hint: l.prototypeEditSubscriptionHint,
          ),
          _menuRow(
            context,
            SourceAction.share,
            LucideIcons.share2,
            l.prototypeShareSubscription,
            hint: l.prototypeShareSubscriptionHint,
          ),
          _menuRow(
            context,
            SourceAction.delete,
            LucideIcons.trash2,
            l.prototypeDelete,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

Widget _menuRow<T>(
  BuildContext context,
  T action,
  IconData icon,
  String title, {
  String? hint,
  bool destructive = false,
}) {
  final palette = ColorManager.palette(context);
  final textColor = destructive ? palette.destructive : palette.foreground;
  return Semantics(
    button: true,
    child: InkWell(
      onTap: () => Navigator.of(context).pop(action),
      hoverColor: palette.surfaceHover,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          border: destructive
              ? null
              : Border(bottom: BorderSide(color: palette.border)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: destructive ? palette.destructive : palette.primary,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Text(
                    title,
                    style: AppTypography.serverMenuTitle.copyWith(
                      color: textColor,
                    ),
                  ),
                  if (hint != null)
                    Text(
                      hint,
                      style: AppTypography.serverMenuHint.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Icon(LucideIcons.arrowRightDir, size: 18, color: textColor),
          ],
        ),
      ),
    ),
  );
}
