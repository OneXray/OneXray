import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/backup/controller.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/date_view.dart';
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
        return PopScope(
          canPop: !state.busy,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.prototypeBackupRestore),
              leading: BackButton(onPressed: () => controller.cancel(context)),
            ),
            body: SafeArea(
              child: SettingsPageScroll(
                child: Column(
                  children: [
                    SettingSection(
                      title: l10n.prototypeBackupContents,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.prototypeBackupAssets),
                              const SizedBox(height: 8),
                              Text(
                                l10n.prototypeBackupNoPreferences,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(LucideIcons.shieldAlert, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.prototypeBackupSecurityWarning,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SettingSection(
                      title:
                          '${l10n.prototypeBackupFiles} (${state.files.length})',
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ShadButton(
                                onPressed: state.busy
                                    ? null
                                    : () => controller.backup(context),
                                leading: const Icon(
                                  LucideIcons.archive,
                                  size: 18,
                                ),
                                child: Text(l10n.prototypeCreateBackup),
                              ),
                              ShadButton.outline(
                                onPressed: state.busy
                                    ? null
                                    : () => controller.importBackup(context),
                                leading: const Icon(
                                  LucideIcons.filePlus2,
                                  size: 18,
                                ),
                                child: Text(l10n.prototypeImportBackup),
                              ),
                            ],
                          ),
                        ),
                        if (state.loading)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        if (state.readFailed)
                          SettingRow(
                            title: l10n.prototypeTemporarilyUnavailable,
                            trailing: IconButton(
                              tooltip: l10n.prototypeRetry,
                              onPressed: state.busy ? null : controller.refresh,
                              icon: const Icon(LucideIcons.refreshCw),
                            ),
                          ),
                        if (!state.loading &&
                            !state.readFailed &&
                            state.files.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(l10n.prototypeNoBackups),
                          ),
                        AbsorbPointer(
                          absorbing: state.busy,
                          child: RadioGroup<String>(
                            groupValue: state.selection,
                            onChanged: controller.updateSelection,
                            child: Column(
                              children: [
                                for (final file in state.files)
                                  _BackupFileRow(
                                    file: file,
                                    selected: state.selection == file.name,
                                    onSelect: () => controller.updateSelection(
                                      state.selection == file.name
                                          ? null
                                          : file.name,
                                    ),
                                    onAction: (action) => controller.moreAction(
                                      context,
                                      file,
                                      action,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: PageActionBar(
              children: [
                ShadButton.outline(
                  onPressed: state.busy
                      ? null
                      : () => controller.cancel(context),
                  child: Text(l10n.prototypeBack),
                ),
                ShadButton(
                  onPressed: state.busy || state.selection.isEmpty
                      ? null
                      : () => controller.restore(context),
                  leading: const Icon(LucideIcons.upload, size: 18),
                  child: Text(l10n.prototypeRestoreSelectedBackup),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _BackupFileRow extends StatelessWidget {
  const _BackupFileRow({
    required this.file,
    required this.selected,
    required this.onSelect,
    required this.onAction,
  });
  final FileInfo file;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<IconMenuId> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DataListRow(
      title: file.name,
      leading: const Icon(LucideIcons.fileArchive),
      meta: file.timestamp == null ? null : DateView(date: file.timestamp!),
      tone: selected ? DataListRowTone.selected : DataListRowTone.normal,
      onTap: onSelect,
      trailing: ActionCluster(
        children: [
          Radio<String>(value: file.name, toggleable: true),
          IconButton(
            tooltip: l10n.prototypeExport,
            onPressed: () => onAction(IconMenuId.save),
            icon: const Icon(LucideIcons.download, size: 18),
          ),
          if (!AppPlatform.isLinux)
            IconButton(
              tooltip: l10n.prototypeShare,
              onPressed: () => onAction(IconMenuId.share),
              icon: const Icon(LucideIcons.share2, size: 18),
            ),
          IconButton(
            tooltip: l10n.prototypeDelete,
            onPressed: () => onAction(IconMenuId.delete),
            icon: const Icon(LucideIcons.trash2, size: 18),
          ),
        ],
      ),
    );
  }
}
