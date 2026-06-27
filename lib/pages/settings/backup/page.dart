import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/settings/backup/controller.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/data_list.dart';
import 'package:onexray/pages/widget/date_view.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BackupController(),
      child: BlocBuilder<BackupController, BackupState>(
        builder: (context, state) {
          final controller = context.read<BackupController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.backupPageTitle),
              actions: [
                IconButton(
                  onPressed: state.backingUp || state.restoring
                      ? null
                      : () => controller.importBackup(context),
                  icon: Icon(Icons.add),
                ),
              ],
            ),
            body: SafeArea(child: _body(context, state, controller)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    BackupState state,
    BackupController controller,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        desktopMaxWidth: 880,
        adaptiveBreakpoint: 840,
        child: Column(
          children: [
            Expanded(child: _fileList(context, state, controller)),
            _bottomButton(context, state, controller),
          ],
        ),
      ),
    );
  }

  Widget _fileList(
    BuildContext context,
    BackupState state,
    BackupController controller,
  ) {
    if (state.files.isEmpty) {
      return ListEmptyView(
        message: AppLocalizations.of(context)!.backupPageNoFiles,
      );
    } else {
      return RadioGroup<String>(
        groupValue: state.selection,
        onChanged: (value) => controller.updateSelection(value),
        child: ListView.separated(
          itemBuilder: (ctx, index) => _itemRow(ctx, state, controller, index),
          itemCount: state.files.length,
          separatorBuilder: (_, _) => const Divider(),
        ),
      );
    }
  }

  Widget _itemRow(
    BuildContext context,
    BackupState state,
    BackupController controller,
    int index,
  ) {
    final file = state.files[index];
    final selected = state.selection == file.name;
    return DataListRow(
      title: file.name,
      meta: DateView(date: file.timestamp!),
      onTap: () => controller.updateSelection(selected ? null : file.name),
      trailing: ActionCluster(
        children: [
          Radio<String>(value: file.name, toggleable: true),
          IconMenuPicker(
            icon: Icons.more_vert,
            menus: [
              if (!AppPlatform.isLinux) IconMenuId.share,
              IconMenuId.save,
              IconMenuId.delete,
            ],
            callback: (menuId) => controller.moreAction(context, file, menuId),
          ),
        ],
      ),
    );
  }

  Widget _bottomButton(
    BuildContext context,
    BackupState state,
    BackupController controller,
  ) {
    final processing = state.backingUp || state.restoring;
    return BottomView(
      child: Row(
        spacing: 12,
        children: [
          if (state.selection.isEmpty)
            Expanded(
              child: SecondaryBottomButton(
                title: AppLocalizations.of(context)!.backupPageRestore,
                callback: null,
                loading: state.restoring,
              ),
            )
          else
            Expanded(
              child: SecondaryBottomButton(
                title: AppLocalizations.of(context)!.backupPageRestore,
                callback: processing ? null : () => controller.restore(context),
                loading: state.restoring,
              ),
            ),
          Expanded(
            child: PrimaryBottomButton(
              title: AppLocalizations.of(context)!.backupPageBackup,
              callback: processing ? null : () => controller.backup(context),
              loading: state.backingUp,
            ),
          ),
        ],
      ),
    );
  }
}
