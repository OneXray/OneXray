import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/assets/import.dart';
import 'package:onexray/service/assets/raw_editor.dart';

class RawEditorController extends ChangeNotifier {
  final RawEditorService service;
  final int? rawId;
  final String? initialText;
  final String? initialName;
  RawEditorController({
    required this.rawId,
    this.initialText,
    this.initialName,
    RawEditorService? service,
  }) : service = service ?? RawEditorService() {
    text.addListener(_changed);
  }
  final name = TextEditingController();
  final text = TextEditingController();
  RawEditorDraft? _draft;
  bool busy = true;
  String? error;
  bool _disposed = false;

  bool get loaded => _draft != null;
  int get lineCount => '\n'.allMatches(text.text).length + 1;
  bool get validJson {
    try {
      return jsonDecode(text.text) is Map;
    } catch (_) {
      return false;
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void closePage(BuildContext context) {
    if (!busy) Navigator.of(context).pop();
  }

  Future<void> load(BuildContext context) async {
    try {
      final draft = await service.load(rawId);
      if (_disposed) return;
      _draft = draft;
      name.text = draft.name;
      text.text = draft.text;
      if (rawId == null && initialText != null) {
        text.text = initialText!;
        final json = jsonDecode(initialText!);
        if (json is! Map<String, dynamic>) {
          throw const FormatException('Invalid JSON');
        }
        name.text = initialName?.isNotEmpty == true
            ? initialName!
            : json['name'] is String
            ? json['name'] as String
            : '';
      }
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeCannotReadContent;
      }
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> importText(
    BuildContext context, {
    required bool clipboard,
  }) async {
    if (busy || !loaded) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final input = clipboard
          ? await ServerImportService.readClipboard()
          : await ServerImportService.pickTextFile(jsonOnly: true);
      if (input == null || !context.mounted) return;
      final json = jsonDecode(input);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Invalid JSON');
      }
      if (_draft!.original != null || text.text != _draft!.text) {
        if (!await ContextAlert.showConfirmDialog(
              context,
              title: l10n.prototypeReplaceEditorJson,
              content: l10n.prototypeJsonImportedIntoEditor,
              confirmLabel: l10n.prototypeImportFile,
            ) ||
            !context.mounted) {
          return;
        }
      }
      text.text = input;
      if (json['name'] is String) name.text = json['name'] as String;
      error = null;
      _changed();
    } catch (_) {
      error = l10n.prototypeCannotReadContent;
      _changed();
    }
  }

  Future<void> save(BuildContext context) async {
    if (busy || !loaded) return;
    busy = true;
    error = null;
    _changed();
    final l10n = AppLocalizations.of(context)!;
    try {
      final id = await service.save(
        RawEditorDraft(
          original: _draft!.original,
          name: name.text,
          text: text.text,
        ),
        confirmReconnect: () => context.mounted
            ? ContextAlert.showConfirmDialog(
                context,
                title: l10n.prototypeApplyChange,
                content: l10n.prototypeReconnectNotice,
                confirmLabel: l10n.prototypeApplyAndReconnect,
              )
            : Future.value(false),
      );
      if (id != null && context.mounted) Navigator.of(context).pop(id);
    } on RawEditorException catch (failure) {
      error = switch (failure.reason) {
        'limit' => l10n.prototypeRawJsonLimit,
        'name' => l10n.validationNameRequired,
        'invalid' => l10n.validationJsonInvalid,
        _ => l10n.buttonSaveFailed,
      };
    } on FormatException {
      error = l10n.validationJsonInvalid;
    } catch (_) {
      error = l10n.buttonSaveFailed;
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    name.dispose();
    text.dispose();
    super.dispose();
  }
}
