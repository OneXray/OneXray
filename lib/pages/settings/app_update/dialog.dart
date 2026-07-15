import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/app_update/controller.dart';
import 'package:onexray/pages/settings/app_update/params.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppUpdateDialogParams params;

  const AppUpdateDialog({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    final controller = AppUpdateDialogController(params.updateInfo);
    return AppUpdateDialogView(
      updateInfo: params.updateInfo,
      onLater: () => controller.later(context),
      onSkip: () => controller.skip(context),
      onUpdate: () => controller.update(context),
      onOpenLink: controller.openLink,
    );
  }
}

class AppUpdateDialogView extends StatelessWidget {
  final AppUpdateInfo updateInfo;
  final VoidCallback onLater;
  final VoidCallback onSkip;
  final VoidCallback onUpdate;
  final ValueChanged<String?> onOpenLink;

  const AppUpdateDialogView({
    super.key,
    required this.updateInfo,
    required this.onLater,
    required this.onSkip,
    required this.onUpdate,
    required this.onOpenLink,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notes = updateInfo.releaseNotes.trim();
    final screenSize = MediaQuery.sizeOf(context);
    final notesHeight = (screenSize.height * 0.42).clamp(160.0, 420.0);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ShadCard(
          width: double.infinity,
          padding: EdgeInsets.zero,
          radius: const BorderRadius.all(Radius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appUpdateDialogTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _VersionGrid(updateInfo: updateInfo),
                  ],
                ),
              ),
              if (notes.isNotEmpty) ...[
                Divider(height: 1, color: ColorManager.border(context)),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: notesHeight),
                  child: Markdown(
                    data: notes,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                    onTapLink: (_, href, _) => onOpenLink(href),
                  ),
                ),
              ],
              Divider(height: 1, color: ColorManager.border(context)),
              _UpdateActions(
                laterLabel: l10n.appUpdateLater,
                skipLabel: l10n.appUpdateSkipVersion,
                updateLabel: l10n.appUpdateOpen,
                onLater: onLater,
                onSkip: onSkip,
                onUpdate: onUpdate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionGrid extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const _VersionGrid({required this.updateInfo});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _row(context, l10n.appUpdateCurrentVersion, updateInfo.currentVersion),
        const SizedBox(height: 8),
        _row(context, l10n.appUpdateLatestVersion, updateInfo.latestVersion),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String version) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: ColorManager.secondaryText(context)),
          ),
        ),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: ColorManager.tagBackground(context),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(version, style: AppTypography.code),
        ),
      ],
    );
  }
}

class _UpdateActions extends StatelessWidget {
  final String laterLabel;
  final String skipLabel;
  final String updateLabel;
  final VoidCallback onLater;
  final VoidCallback onSkip;
  final VoidCallback onUpdate;

  const _UpdateActions({
    required this.laterLabel,
    required this.skipLabel,
    required this.updateLabel,
    required this.onLater,
    required this.onSkip,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: ColorManager.tagBackground(context).withValues(alpha: 0.45),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = [
            ShadButton.outline(onPressed: onLater, child: Text(laterLabel)),
            ShadButton.outline(onPressed: onSkip, child: Text(skipLabel)),
            ShadButton(onPressed: onUpdate, child: Text(updateLabel)),
          ];
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  actions[index],
                ],
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                actions[index],
              ],
            ],
          );
        },
      ),
    );
  }
}
