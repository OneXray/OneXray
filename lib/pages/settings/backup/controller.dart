import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/share/backup.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

class FileInfo {
  final String name;
  final String path;
  DateTime? timestamp;

  FileInfo(this.name, this.path);
}

class BackupPageState {
  final List<FileInfo> files;
  final String selection;
  final bool backingUp;
  final bool restoring;
  final bool importing;
  final String restoringPath;
  final Map<String, IconMenuId> fileActions;
  final bool loading;
  final bool readFailed;

  const BackupPageState({
    this.files = const [],
    this.selection = "",
    this.backingUp = false,
    this.restoring = false,
    this.importing = false,
    this.restoringPath = '',
    this.fileActions = const {},
    this.loading = true,
    this.readFailed = false,
  });

  bool get canBackup => !backingUp && !restoring && !importing;
  // Import can replace an existing archive with the same creation timestamp.
  bool get canImport => canBackup && fileActions.isEmpty;
  bool get transferring => fileActions.values.any(
    (action) => action == IconMenuId.share || action == IconMenuId.save,
  );
  bool fileBusy(String path) =>
      importing || fileActions.containsKey(path) || restoringPath == path;
  bool get canRestore =>
      canBackup &&
      files.any((file) => file.name == selection && !fileBusy(file.path));

  BackupPageState copyWith({
    List<FileInfo>? files,
    String? selection,
    bool? backingUp,
    bool? restoring,
    bool? importing,
    String? restoringPath,
    Map<String, IconMenuId>? fileActions,
    bool? loading,
    bool? readFailed,
  }) {
    return BackupPageState(
      files: files ?? this.files,
      selection: selection ?? this.selection,
      backingUp: backingUp ?? this.backingUp,
      restoring: restoring ?? this.restoring,
      importing: importing ?? this.importing,
      restoringPath: restoringPath ?? this.restoringPath,
      fileActions: fileActions ?? this.fileActions,
      loading: loading ?? this.loading,
      readFailed: readFailed ?? this.readFailed,
    );
  }
}

class BackupController extends PageCubit<BackupPageState> {
  BackupController() : super(const BackupPageState()) {
    _readFiles();
  }
  int _readGeneration = 0;

  Future<void> _readFiles({
    bool selectNewest = false,
    bool showLoading = true,
  }) async {
    if (!isPageActive) return;
    final generation = ++_readGeneration;
    emit(state.copyWith(loading: showLoading, readFailed: false));
    try {
      final backupDir = await BackupService().backupDir;
      final zipFiles = await Directory(backupDir)
          .list(followLinks: false)
          .toList();
      final fileInfos = <FileInfo>[];
      for (final file in zipFiles) {
        if (file is File && file.path.endsWith(".zip")) {
          final info = FileInfo(p.basename(file.path), file.path);
          try {
            info.timestamp = await File(file.path).lastModified();
          } catch (_) {}
          fileInfos.add(info);
        }
      }
      fileInfos.sort((a, b) {
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      if (!isPageActive || generation != _readGeneration) return;
      final selection = selectNewest && fileInfos.isNotEmpty
          ? fileInfos.first.name
          : fileInfos.any((file) => file.name == state.selection)
          ? state.selection
          : "";
      emit(state.copyWith(files: fileInfos, selection: selection));
    } catch (_) {
      if (generation == _readGeneration) {
        emit(state.copyWith(readFailed: true));
      }
    } finally {
      if (generation == _readGeneration) {
        emit(state.copyWith(loading: false));
      }
    }
  }

  Future<void> refresh() async {
    if (!state.loading) await _readFiles();
  }

  void cancel(BuildContext context) {
    Navigator.of(context).pop();
  }

  void updateSelection(String? value) {
    if (value == state.selection) return;
    if (value == null) {
      emit(state.copyWith(selection: ""));
    } else {
      emit(state.copyWith(selection: value));
    }
  }

  Future<void> importBackup(BuildContext context) async {
    if (!state.canImport) return;
    emit(state.copyWith(importing: true));
    try {
      final success = await BackupService().importBackup();
      if (success == null) return;
      if (context.mounted) {
        _showActionResult(
          context,
          success,
          AppLocalizations.of(context)!.prototypeImportBackup,
        );
      }
      await _readFiles(selectNewest: success, showLoading: false);
    } catch (_) {
      if (context.mounted) {
        _showActionResult(
          context,
          false,
          AppLocalizations.of(context)!.prototypeImportBackup,
        );
      }
    } finally {
      emit(state.copyWith(importing: false));
    }
  }

  Future<void> moreAction(
    BuildContext context,
    FileInfo file,
    IconMenuId menuId,
  ) async {
    if (state.fileBusy(file.path) ||
        !state.files.any((entry) => entry.path == file.path)) {
      return;
    }
    if (state.transferring &&
        (menuId == IconMenuId.share || menuId == IconMenuId.save)) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final action = switch (menuId) {
      IconMenuId.share => l10n.prototypeShare,
      IconMenuId.save => l10n.prototypeExport,
      IconMenuId.delete => l10n.prototypeDelete,
      _ => null,
    };
    if (action == null) return;
    emit(
      state.copyWith(fileActions: {...state.fileActions, file.path: menuId}),
    );
    try {
      final confirmed = await AppConfirmationDialog(
        title: switch (menuId) {
          IconMenuId.delete => l10n.prototypeDeleteBackupQuestion,
          IconMenuId.share => l10n.prototypeShareBackup,
          _ => l10n.prototypeExportBackup,
        },
        subject: file.name,
        content: menuId == IconMenuId.delete
            ? l10n.prototypeDeleteBackupWarning
            : l10n.prototypeBackupTransferWarning,
        cancelLabel: l10n.prototypeCancel,
        confirmLabel: menuId == IconMenuId.delete
            ? action
            : l10n.prototypeContinue,
        destructive: menuId == IconMenuId.delete,
        expandConfirm: menuId != IconMenuId.delete,
      ).show(context);
      if (!confirmed || !context.mounted) return;
      switch (menuId) {
        case IconMenuId.share:
          await _shareFile(context, file);
          break;
        case IconMenuId.save:
          await _saveFile(context, file);
          break;
        case IconMenuId.delete:
          await _deleteFile(file);
          break;
        default:
          break;
      }
    } catch (_) {
      if (context.mounted) _showActionResult(context, false, action);
    } finally {
      emit(
        state.copyWith(fileActions: {...state.fileActions}..remove(file.path)),
      );
    }
  }

  Future<void> _shareFile(BuildContext context, FileInfo file) async {
    Rect? sharePositionOrigin;
    if (context.mounted) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    final params = ShareParams(
      files: [XFile(file.path)],
      fileNameOverrides: [file.name],
      sharePositionOrigin: sharePositionOrigin,
    );
    final result = await SharePlus.instance.share(params);
    if (context.mounted && result.status != ShareResultStatus.dismissed) {
      _showActionResult(
        context,
        result.status == ShareResultStatus.success,
        AppLocalizations.of(context)!.prototypeShare,
      );
    }
  }

  void _showActionResult(BuildContext context, bool success, String action) {
    if (success) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!
            .actionResult(action, AppLocalizations.of(context)!.resultSuccess),
      );
    } else {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!
            .actionResult(action, AppLocalizations.of(context)!.resultFailed),
      );
    }
  }

  Future<void> _saveFile(BuildContext context, FileInfo file) async {
    final success = await FileTool.saveFile(file.path, file.name, ".zip");
    if (context.mounted) {
      _showActionResult(
        context,
        success,
        AppLocalizations.of(context)!.prototypeExport,
      );
    }
  }

  Future<void> _deleteFile(FileInfo file) async {
    await File(file.path).delete();
    await _readFiles(showLoading: false);
  }

  Future<void> backup(BuildContext context) async {
    if (!state.canBackup) return;
    emit(state.copyWith(backingUp: true));
    try {
      await BackupService().backup();
      await _readFiles(selectNewest: true, showLoading: false);
    } catch (_) {
      if (context.mounted) {
        _showActionResult(
          context,
          false,
          AppLocalizations.of(context)!.prototypeCreateBackup,
        );
      }
    } finally {
      if (isPageActive) {
        emit(state.copyWith(backingUp: false));
      }
    }
  }

  Future<void> restore(BuildContext context) async {
    if (!state.canRestore) return;
    final file = state.files
        .where((e) => e.name == state.selection)
        .firstOrNull;
    if (file == null) return;
    final l10n = AppLocalizations.of(context)!;
    emit(state.copyWith(restoring: true, restoringPath: file.path));
    try {
      final confirmed = await AppConfirmationDialog(
        title: l10n.prototypeRestoreBackupQuestion,
        subject: file.name,
        content: l10n.prototypeRestoreBackupWarning,
        cancelLabel: l10n.prototypeCancel,
        confirmLabel: l10n.prototypeConfirmRestore,
        expandConfirm: true,
      ).show(context);
      if (!confirmed || !context.mounted) return;
      final success = await BackupService().restore(file.path);
      if (context.mounted) {
        _showActionResult(context, success, l10n.backupPageRestore);
      }
    } catch (_) {
      if (context.mounted) {
        _showActionResult(context, false, l10n.backupPageRestore);
      }
    } finally {
      if (isPageActive) {
        emit(state.copyWith(restoring: false, restoringPath: ''));
      }
    }
  }
}
