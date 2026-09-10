import 'package:onexray/service/shared/failure.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/xray/config/params.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/pages/shared/widgets/settings_page.dart';
import 'package:onexray/service/advanced/xray/runtime_files.dart';

class ConfigFileViewerPageState {
  final String title;
  final String text;
  final String? displayText;
  final bool loading;
  final bool failed;
  final Object? failure;
  final bool exporting;
  const ConfigFileViewerPageState({
    this.title = '',
    this.text = '',
    this.displayText,
    this.loading = true,
    this.failed = false,
    this.failure,
    this.exporting = false,
  });
  ConfigFileViewerPageState copyWith({
    String? text,
    String? displayText,
    bool? loading,
    bool? failed,
    Object? failure,
    bool? exporting,
  }) => ConfigFileViewerPageState(
    title: title,
    text: text ?? this.text,
    displayText: displayText ?? this.displayText,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    failure: failed == false ? null : failure ?? this.failure,
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
      var displayText = text;
      try {
        displayText = const JsonEncoder.withIndent('  ')
            .convert(jsonDecode(text));
      } on FormatException {
        // Keep the original text when it cannot be formatted as JSON.
      }
      emit(
        state.copyWith(text: text, displayText: displayText, loading: false),
      );
    } catch (error) {
      emit(state.copyWith(loading: false, failed: true, failure: error));
    }
  }

  Future<void> shareFile(BuildContext context) async {
    if (state.loading || state.failed || state.exporting) return;
    final l = AppLocalizations.of(context)!;
    emit(state.copyWith(exporting: true));
    try {
      final confirmed = await AppConfirmationDialog(
        title: l.prototypeExportOriginalConfigurationQuestion,
        content: l.prototypeExportOriginalConfigurationWarning,
        cancelLabel: l.prototypeCancel,
        confirmLabel: l.prototypeExport,
      ).show(context);
      if (confirmed != true || !isPageActive) return;
      await RuntimeDiagnosticFiles.exportConfiguration(state.text);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appFailureMessage(
                l,
                error,
                operation: l.actionResult(l.prototypeExport, l.resultFailed),
              ),
            ),
          ),
        );
      }
    } finally {
      emit(state.copyWith(exporting: false));
    }
  }
}
