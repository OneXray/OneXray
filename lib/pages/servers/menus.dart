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
          _row(
            context,
            ServerAction.edit,
            LucideIcons.pencil,
            l.prototypeEditServer,
            hint: l.prototypeEditServerHint,
          ),
          _row(
            context,
            ServerAction.test,
            LucideIcons.refreshCw,
            l.prototypeTestAgain,
            hint: l.prototypeRetestHint,
          ),
          _row(
            context,
            ServerAction.copy,
            LucideIcons.copy,
            l.prototypeSaveAsLocalServer,
            hint: l.prototypeLocalCopyHint,
          ),
          _row(
            context,
            ServerAction.share,
            LucideIcons.share2,
            l.prototypeShareServer,
            hint: l.prototypeShareServerHint,
          ),
          _row(
            context,
            ServerAction.delete,
            LucideIcons.trash2,
            l.prototypeDelete,
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ServerAction action,
    IconData icon,
    String title, {
    String? hint,
  }) {
    final palette = ColorManager.palette(context);
    final destructive = action == ServerAction.delete;
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
}
