import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class BackupState {
  final List<FileInfo> files;
  final String selection;

  const BackupState({this.files = const [], this.selection = ""});

  BackupState copyWith({List<FileInfo>? files, String? selection}) {
    return BackupState(
      files: files ?? this.files,
      selection: selection ?? this.selection,
    );
  }
}

class BackupController extends Cubit<BackupState> {
  BackupController() : super(const BackupState()) {
    _readFiles();
  }

  Future<void> _readFiles() async {
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

    emit(state.copyWith(files: fileInfos));
  }

  void updateSelection(String? value) {
    if (value == null) {
      emit(state.copyWith(selection: ""));
    } else {
      emit(state.copyWith(selection: value));
    }
  }

  Future<void> importBackup(BuildContext context) async {
    final success = await BackupService().importBackup();
    if (context.mounted) {
      _showActionResult(
        context,
        success,
        AppLocalizations.of(context)!.backupPageImport,
      );
    }
    await _readFiles();
  }

  Future<void> moreAction(
    BuildContext context,
    FileInfo file,
    String menuId,
  ) async {
    final id = IconMenuId.fromString(menuId);
    if (id == null) {
      return;
    }
    switch (id) {
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
    await BackupService().backup();
    await _readFiles();
  }

  Future<void> restore(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.backupPageRestoreTips),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.buttonCancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text(AppLocalizations.of(context)!.buttonOK),
            onPressed: () {
              Navigator.pop(ctx);
              _restore(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final zipPath = state.files
        .where((e) => e.name == state.selection)
        .firstOrNull
        ?.path;
    var success = false;
    if (zipPath != null) {
      success = await BackupService().restore(zipPath);
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
