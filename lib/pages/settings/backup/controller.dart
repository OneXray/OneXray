import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
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

  const BackupPageState({
    this.files = const [],
    this.selection = "",
    this.backingUp = false,
    this.restoring = false,
  });

  BackupPageState copyWith({
    List<FileInfo>? files,
    String? selection,
    bool? backingUp,
    bool? restoring,
  }) {
    return BackupPageState(
      files: files ?? this.files,
      selection: selection ?? this.selection,
      backingUp: backingUp ?? this.backingUp,
      restoring: restoring ?? this.restoring,
    );
  }
}

class BackupController extends PageCubit<BackupPageState> {
  BackupController() : super(const BackupPageState()) {
    _readFiles();
  }

  Future<void> _readFiles({bool selectNewest = false}) async {
    final backupDir = await BackupService().backupDir;
    final zipFiles = await Directory(backupDir).list().toList();
    final fileInfos = <FileInfo>[];
    for (final file in zipFiles) {
      if (file.path.endsWith(".zip")) {
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
    final selection = selectNewest && fileInfos.isNotEmpty
        ? fileInfos.first.name
        : fileInfos.any((file) => file.name == state.selection)
        ? state.selection
        : "";
    emit(state.copyWith(files: fileInfos, selection: selection));
  }

  void updateSelection(String? value) {
    if (value == null) {
      emit(state.copyWith(selection: ""));
    } else {
      emit(state.copyWith(selection: value));
    }
  }

  Future<void> importBackup(BuildContext context) async {
    if (state.backingUp || state.restoring) {
      return;
    }
    final success = await BackupService().importBackup();
    if (context.mounted) {
      _showActionResult(
        context,
        success,
        AppLocalizations.of(context)!.backupPageImport,
      );
    }
    await _readFiles(selectNewest: success);
  }

  Future<void> moreAction(
    BuildContext context,
    FileInfo file,
    IconMenuId menuId,
  ) async {
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
    if (context.mounted) {
      _showActionResult(
        context,
        result.status == ShareResultStatus.success,
        AppLocalizations.of(context)!.menuShare,
      );
    }
  }

  void _showActionResult(BuildContext context, bool success, String action) {
    if (success) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(
          context,
        )!.actionResult(action, AppLocalizations.of(context)!.resultSuccess),
      );
    } else {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(
          context,
        )!.actionResult(action, AppLocalizations.of(context)!.resultFailed),
      );
    }
  }

  Future<void> _saveFile(BuildContext context, FileInfo file) async {
    final success = await FileTool.saveFile(file.path, file.name, ".zip");
    if (context.mounted) {
      _showActionResult(
        context,
        success,
        AppLocalizations.of(context)!.menuSave,
      );
    }
  }

  Future<void> _deleteFile(FileInfo file) async {
    await File(file.path).delete();
    await _readFiles();
  }

  Future<void> backup(BuildContext context) async {
    if (state.backingUp || state.restoring) {
      return;
    }
    emit(state.copyWith(backingUp: true));
    try {
      await BackupService().backup();
      await _readFiles(selectNewest: true);
    } finally {
      if (isPageActive) {
        emit(state.copyWith(backingUp: false));
      }
    }
  }

  Future<void> restore(BuildContext context) async {
    if (state.backingUp || state.restoring) {
      return;
    }
    final restoreConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final localizations = AppLocalizations.of(ctx)!;
        return AlertDialog(
          content: Text(localizations.backupPageRestoreTips),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.buttonCancel),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            TextButton(
              child: Text(localizations.buttonOK),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );
    if (restoreConfirmed == true && context.mounted) {
      await _restore(context);
    }
  }

  Future<void> _restore(BuildContext context) async {
    if (state.backingUp || state.restoring) {
      return;
    }
    final zipPath = state.files
        .where((e) => e.name == state.selection)
        .firstOrNull
        ?.path;
    var success = false;
    if (zipPath != null) {
      emit(state.copyWith(restoring: true));
      try {
        success = await BackupService().restore(zipPath);
      } finally {
        if (isPageActive) {
          emit(state.copyWith(restoring: false));
        }
      }
    }
    if (context.mounted) {
      _showActionResult(
        context,
        success,
        AppLocalizations.of(context)!.backupPageRestore,
      );
    }
  }
}
