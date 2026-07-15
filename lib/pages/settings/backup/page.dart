import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/backup/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/date_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BackupController(),
      child: BlocBuilder<BackupController, BackupPageState>(
        builder: (context, state) {
          final controller = context.read<BackupController>();
          final localizations = AppLocalizations.of(context)!;
          return SettingsPageScaffold(
            title: localizations.backupPageTitle,
            actions: [
              IconButton(
                tooltip: localizations.backupPageImport,
                onPressed: state.backingUp || state.restoring
                    ? null
                    : () => controller.importBackup(context),
                icon: const Icon(LucideIcons.filePlus2),
              ),
            ],
            body: _body(context, state, controller),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    BackupPageState state,
    BackupController controller,
  ) {
    return Column(
      children: [
        Expanded(
          child: ResponsiveContent(
            desktopMaxWidth: 920,
            adaptiveBreakpoint: 840,
            child: _fileList(context, state, controller),
          ),
        ),
        _actionBar(context, state, controller),
      ],
    );
  }

  Widget _fileList(
    BuildContext context,
    BackupPageState state,
    BackupController controller,
  ) {
    if (state.files.isEmpty) {
      return ListEmptyView(
        message: AppLocalizations.of(context)!.backupPageNoFiles,
        icon: LucideIcons.archive,
      );
    } else {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 12),
        child: ShadCard(
          width: double.infinity,
          padding: EdgeInsets.zero,
          radius: const BorderRadius.all(Radius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: RadioGroup<String>(
            groupValue: state.selection,
            onChanged: controller.updateSelection,
            child: ListView.separated(
              itemBuilder: (ctx, index) =>
                  _itemRow(ctx, state, controller, index),
              itemCount: state.files.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
            ),
          ),
        ),
      );
    }
  }

  Widget _itemRow(
    BuildContext context,
    BackupPageState state,
    BackupController controller,
    int index,
  ) {
    final file = state.files[index];
    final selected = state.selection == file.name;
    return DataListRow(
      title: file.name,
      leading: const Icon(LucideIcons.fileArchive),
      meta: DateView(date: file.timestamp!),
      tone: selected ? DataListRowTone.selected : DataListRowTone.normal,
      onTap: () => controller.updateSelection(selected ? null : file.name),
      trailing: ActionCluster(
        children: [
          Radio<String>(value: file.name, toggleable: true),
          AppMenuButton<IconMenuId>(
            icon: LucideIcons.ellipsisVertical,
            entries: iconMenuEntries([
              if (!AppPlatform.isLinux) IconMenuId.share,
              IconMenuId.save,
              IconMenuId.delete,
            ]),
            onSelected: (menuId) =>
                controller.moreAction(context, file, menuId),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(
    BuildContext context,
    BackupPageState state,
    BackupController controller,
  ) {
    final processing = state.backingUp || state.restoring;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final restore = _restoreButton(context, state, controller, processing);
        final backup = _backupButton(context, state, controller, processing);
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: compact ? 62 : 64),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: compact ? 12 : 22,
            vertical: compact ? 9 : 10,
          ),
          decoration: BoxDecoration(
            color: ColorManager.surface(context),
            border: Border(
              top: BorderSide(color: ColorManager.border(context)),
            ),
          ),
          child: Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: compact
                ? [
                    Expanded(child: restore),
                    const SizedBox(width: 10),
                    Expanded(child: backup),
                  ]
                : [
                    SizedBox(width: 128, child: restore),
                    const SizedBox(width: 10),
                    SizedBox(width: 128, child: backup),
                  ],
          ),
        );
      },
    );
  }

  Widget _restoreButton(
    BuildContext context,
    BackupPageState state,
    BackupController controller,
    bool processing,
  ) {
    return ShadButton.outline(
      width: double.infinity,
      height: 40,
      leading: state.restoring
          ? const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.upload, size: 16),
      onPressed: state.selection.isEmpty || processing
          ? null
          : () => controller.restore(context),
      child: Text(AppLocalizations.of(context)!.backupPageRestore),
    );
  }

  Widget _backupButton(
    BuildContext context,
    BackupPageState state,
    BackupController controller,
    bool processing,
  ) {
    return ShadButton(
      width: double.infinity,
      height: 40,
      leading: state.backingUp
          ? const SizedBox.square(
              dimension: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.archive, size: 16),
      onPressed: processing ? null : () => controller.backup(context),
      child: Text(AppLocalizations.of(context)!.backupPageBackup),
    );
  }
}
