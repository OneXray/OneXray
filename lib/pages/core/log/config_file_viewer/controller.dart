import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/log/config_file_viewer/params.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/xray/runtime_files.dart';

class ConfigFileViewerPageState {
  final String title;
  final String text;
  final bool loading;
  final bool failed;
  final bool exporting;
  const ConfigFileViewerPageState({
    this.title = '',
    this.text = '',
    this.loading = true,
    this.failed = false,
    this.exporting = false,
  });
  ConfigFileViewerPageState copyWith({
    String? text,
    bool? loading,
    bool? failed,
    bool? exporting,
  }) => ConfigFileViewerPageState(
    title: title,
    text: text ?? this.text,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    exporting: exporting ?? this.exporting,
  );
}

class ConfigFileViewerController extends PageCubit<ConfigFileViewerPageState> {
  final ConfigFileViewerParams params;
  ConfigFileViewerController(this.params)
    : super(ConfigFileViewerPageState(title: params.title)) {
    load();
  }

  Future<void> load() async {
    try {
      final text = await RuntimeDiagnosticFiles.readConfiguration(
        text: params.text,
        path: params.path,
      );
      emit(state.copyWith(text: text, loading: false));
    } catch (_) {
      emit(state.copyWith(loading: false, failed: true));
    }
  }

  Future<void> shareFile(BuildContext context) async {
    if (state.loading || state.failed || state.exporting) return;
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.prototypeExportOriginalConfigurationQuestion),
        content: Text(l.prototypeExportOriginalConfigurationWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.prototypeCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.prototypeExport),
          ),
        ],
      ),
    );
    if (confirmed != true || !isPageActive) return;
    emit(state.copyWith(exporting: true));
    try {
      await RuntimeDiagnosticFiles.exportConfiguration(state.text);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.prototypeTemporarilyUnavailable)),
        );
      }
    } finally {
      emit(state.copyWith(exporting: false));
    }
  }
}
