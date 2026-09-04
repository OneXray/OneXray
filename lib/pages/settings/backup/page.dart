import 'package:flutter/material.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/backup/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => BackupController(),
    child: BlocBuilder<BackupController, BackupPageState>(
      builder: (context, state) {
        final controller = context.read<BackupController>();
        final l10n = AppLocalizations.of(context)!;
        final palette = ColorManager.palette(context);
        final mobile =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.prototypeBackupRestore),
            leading: BackButton(onPressed: () => controller.cancel(context)),
          ),
          body: SafeArea(
            child: SettingsPageScroll(
              desktopMaxWidth: AppLayout.routingMaxWidth,
              alignment: AlignmentDirectional.topStart,
              padding: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 14 : AppSpacing.page,
                  mobile ? 17 : AppSpacing.desktopPageTop,
                  mobile ? 14 : AppSpacing.page,
                  mobile ? 26 : AppSpacing.desktopPageBottom + 26,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: mobile ? 23 : 24,
                  children: [
                    if (mobile)
                      Text(
                        l10n.prototypeBackupRestoreHint,
                        style: AppTypography.settingsDetailNote.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingSection(
                          title: l10n.prototypeBackupContents,
                          icon: LucideIcons.hardDrive,
                          headerInset: 0,
                          padding: EdgeInsets.zero,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l10n.prototypeBackupAssets,
                                    style: AppTypography.backupBody,
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    l10n.prototypeBackupNoPreferences,
                                    style: AppTypography.backupScopeHint
                                        .copyWith(
                                          color: palette.mutedForeground,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                LucideIcons.shield,
                                size: 16,
                                color: palette.mutedForeground,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                l10n.prototypeBackupSecurityWarning,
                                style: AppTypography.settingsDetailNote
                                    .copyWith(color: palette.mutedForeground),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: mobile ? 20 : 24,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.prototypeBackupFiles,
                                  style: mobile
                                      ? AppTypography.settingsSectionTitle
                                      : AppTypography
                                            .settingsSectionDesktopTitle,
                                ),
                              ),
                              Text(
                                '${state.files.length}',
                                style: AppTypography.settingsDetailNote
                                    .copyWith(color: palette.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: mobile ? 11 : 13),
                        Row(
                          spacing: 10,
                          children: [
                            for (final tool in [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 42,
                                ),
                                child: ShadButton.outline(
                                  enabled: state.canBackup,
                                  expands: mobile,
                                  height: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 10,
                                  ),
                                  onPressed: () => controller.backup(context),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (state.backingUp)
                                        const ButtonProgressIndicator(size: 17)
                                      else
                                        const Icon(LucideIcons.plus, size: 17),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(l10n.prototypeCreateBackup),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 42,
                                ),
                                child: ShadButton.outline(
                                  enabled: state.canImport,
                                  expands: mobile,
                                  height: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 10,
                                  ),
                                  onPressed: () =>
                                      controller.importBackup(context),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (state.importing)
                                        const ButtonProgressIndicator(size: 17)
                                      else
                                        const Icon(
                                          LucideIcons.download,
                                          size: 17,
                                        ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(l10n.prototypeImportBackup),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ])
                              if (mobile) Expanded(child: tool) else tool,
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (state.loading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        if (state.readFailed)
                          SettingRow(
                            title: l10n.prototypeTemporarilyUnavailable,
                            enabled: !state.loading,
                            trailing: IconButton(
                              tooltip: l10n.prototypeRetry,
                              onPressed: state.loading
                                  ? null
                                  : controller.refresh,
                              icon: state.loading
                                  ? const ButtonProgressIndicator()
                                  : const Icon(LucideIcons.refreshCw),
                            ),
                          ),
                        if (!state.loading &&
                            !state.readFailed &&
                            state.files.isEmpty)
                          CustomPaint(
                            painter: _BackupEmptyBorder(palette.border),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 175),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.hardDrive,
                                    size: 29,
                                    color: palette.mutedForeground,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.prototypeNoBackups,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.backupEmptyTitle,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (state.files.isNotEmpty)
                          ShadRadioGroup<String>(
                            axis: Axis.horizontal,
                            initialValue: state.selection,
                            onChanged: controller.updateSelection,
                            items: [
                              SettingSection(
                                title: '',
                                padding: EdgeInsets.zero,
                                dividerIndent: 0,
                                children: [
                                  for (final file in state.files)
                                    _BackupFileRow(
                                      file: file,
                                      selected: state.selection == file.name,
                                      enabled: !state.fileBusy(file.path),
                                      action: state.fileActions[file.path],
                                      canTransfer: !state.transferring,
                                      onSelect: () =>
                                          controller.updateSelection(file.name),
                                      onAction: (action) => controller
                                          .moreAction(context, file, action),
                                    ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: PageActionBar(
            maxWidth: AppLayout.routingEditorMaxWidth,
            children: [
              ShadButton.outline(
                onPressed: () => controller.cancel(context),
                child: Text(l10n.prototypeBack),
              ),
              ShadButton(
                enabled: state.canRestore,
                onPressed: () => controller.restore(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state.restoring)
                      const ButtonProgressIndicator(size: 17)
                    else
                      const Icon(LucideIcons.rotateCcw, size: 17),
                    const SizedBox(width: 8),
                    Flexible(child: Text(l10n.prototypeRestoreSelectedBackup)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _BackupEmptyBorder extends CustomPainter {
  const _BackupEmptyBorder(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          const Radius.circular(AppRadii.card),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 6) {
        canvas.drawPath(metric.extractPath(start, start + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BackupEmptyBorder oldDelegate) =>
      oldDelegate.color != color;
}

class _BackupFileRow extends StatelessWidget {
  const _BackupFileRow({
    required this.file,
    required this.selected,
    required this.enabled,
    required this.onSelect,
    required this.onAction,
    this.action,
    this.canTransfer = true,
  });
  final FileInfo file;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelect;
  final ValueChanged<IconMenuId> onAction;
  final IconMenuId? action;
  final bool canTransfer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: selected ? palette.selectedSurface : Colors.transparent,
          child: MergeSemantics(
            child: InkWell(
              onTap: enabled ? onSelect : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 78),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  spacing: 13,
                  children: [
                    Icon(
                      LucideIcons.fileText,
                      size: 20,
                      color: palette.primary,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            file.name,
                            style: AppTypography.settingsChoiceTitle,
                          ),
                          if (file.timestamp != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              DateFormat.yMd(
                                Localizations.localeOf(context).toString(),
                              ).add_Hms().format(file.timestamp!),
                              style: AppTypography.settingsChoiceDetail
                                  .copyWith(color: palette.mutedForeground),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ShadRadio<String>(
                      value: file.name,
                      enabled: enabled,
                      radioPadding: EdgeInsets.zero,
                      decoration: selected
                          ? ShadDecoration(
                              border: ShadBorder.all(
                                color: palette.primary,
                                width: 1,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionButton(
                context,
                l10n.prototypeExport,
                IconMenuId.save,
                icon: LucideIcons.download,
              ),
              if (!AppPlatform.isLinux)
                _actionButton(context, l10n.prototypeShare, IconMenuId.share),
              _actionButton(
                context,
                l10n.prototypeDelete,
                IconMenuId.delete,
                icon: LucideIcons.trash2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context,
    String label,
    IconMenuId action, {
    IconData? icon,
  }) {
    final destructive = action == IconMenuId.delete;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: ShadButton.outline(
        enabled: enabled && (action == IconMenuId.delete || canTransfer),
        height: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        foregroundColor: destructive
            ? ColorManager.palette(context).destructive
            : null,
        hoverForegroundColor: destructive
            ? ColorManager.palette(context).destructive
            : null,
        textStyle: AppTypography.backupAction,
        leading: this.action == action
            ? const ButtonProgressIndicator(size: 15)
            : icon == null
            ? null
            : Icon(icon, size: 15),
        onPressed: () => onAction(action),
        child: Text(label),
      ),
    );
  }
}
