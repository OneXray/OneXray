import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';

class ServerSourcesDialog extends StatelessWidget {
  const ServerSourcesDialog({super.key, required this.controller});

  final ServersController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AppDialog(
      title: l.prototypeManageSources,
      subtitle: l.prototypeSourceUpdateGuard,
      body: ListenableBuilder(
        listenable: Listenable.merge([
          controller,
          controller.coordinator.state,
        ]),
        builder: (context, _) {
          final material = MaterialLocalizations.of(context);
          final localCount = controller.sourceCount(0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.actionBusy) const LinearProgressIndicator(),
                if (controller.sources.isEmpty && localCount == 0)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l.prototypeNoServersYet),
                  ),
                for (final source in controller.sources)
                  _SourceRow(
                    name: source.name,
                    detail:
                        '${l.prototypeServerCount(controller.sourceCount(source.id))} · '
                        '${material.formatMediumDate(source.timestamp.toLocal())} '
                        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(source.timestamp.toLocal()))}',
                    status:
                        controller.sourceErrors[source.id] ??
                        l.prototypeUpdated,
                    failed: controller.sourceErrors.containsKey(source.id),
                    showDivider:
                        source != controller.sources.last || localCount > 0,
                    subscription: true,
                    onMore: controller.busy
                        ? null
                        : () =>
                              Navigator.of(context)
                                  .pop<SubscriptionData>(source),
                    onUpdate: controller.busy
                        ? null
                        : () => controller.sourceAction(
                            context,
                            source,
                            SourceAction.update,
                          ),
                  ),
                if (localCount > 0)
                  _SourceRow(
                    name: l.prototypeManualAdditions,
                    detail:
                        '${l.prototypeServerCount(localCount)} · ${l.prototypeLocalOnly}',
                    status: l.prototypeStoredOnThisDevice,
                    showDivider: false,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.name,
    required this.detail,
    required this.status,
    required this.showDivider,
    this.subscription = false,
    this.failed = false,
    this.onMore,
    this.onUpdate,
  });

  final String name;
  final String detail;
  final String status;
  final bool showDivider;
  final bool subscription;
  final bool failed;
  final VoidCallback? onMore;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final statusLabel = Text(
      status,
      style: AppTypography.serverSelectionHealth.copyWith(
        color: failed ? palette.destructive : palette.running,
      ),
    );
    final actionStyle = IconButton.styleFrom(
      foregroundColor: palette.mutedStrong,
      iconSize: 18,
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(36),
      fixedSize: const Size.square(36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 18, vertical: 11),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: palette.border))
            : null,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.link2, size: 20, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.serverMenuTitle.copyWith(
                    color: palette.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.serverMenuHint.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
                if (mobile) ...[const SizedBox(height: 10), statusLabel],
              ],
            ),
          ),
          if (!mobile) ...[const SizedBox(width: 10), statusLabel],
          if (subscription) ...[
            if (!mobile) ...[
              const SizedBox(width: 10),
              IconButton(
                tooltip: l.prototypeCheckForUpdates,
                style: actionStyle,
                onPressed: onUpdate,
                icon: const Icon(LucideIcons.refreshCw),
              ),
            ],
            const SizedBox(width: 10),
            IconButton(
              tooltip: '${l.prototypeMoreActions}: $name',
              style: actionStyle,
              onPressed: onMore,
              icon: const Icon(LucideIcons.ellipsis),
            ),
          ],
        ],
      ),
    );
  }
}
