import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/configuration_transfer.dart';
import 'package:onexray/service/assets/raw_editor.dart';
import 'package:onexray/service/share/configuration_transfer.dart';

enum RawEditorAction { test, save }

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
    name.addListener(_notify);
    transfers.addListener(_transferChanged);
  }
  final name = TextEditingController();
  final text = TextEditingController();
  RawEditorDraft? _draft;
  bool busy = true;
  RawEditorAction? action;
  String? error;
  bool _disposed = false;
  RawTestResult? testResult;
  int? sharingDataCount;
  int _textRevision = 0;
  late final transfers = ConfigurationTransferController(
    kind: ConfigurationKind.raw,
    readText: () => text.text,
    readName: () => name.text,
    onImport: (draft) {
      text.text = draft.text;
      if (name.text.trim().isEmpty && draft.name.isNotEmpty) {
        name.text = draft.name;
      }
      error = null;
    },
  );

  bool get working => busy || transfers.busy;

  bool get loaded => _draft != null;
  bool get canTest => !working && loaded && text.text.trim().isNotEmpty;
  bool get canSave => canTest && name.text.trim().isNotEmpty;
  int get lineCount => '\n'.allMatches(text.text).length + 1;
  void _changed() {
    if (_disposed) return;
    testResult = null;
    _updateSharingDataCount();
    _notify();
  }

  void _transferChanged() {
    if (_disposed) return;
    _updateSharingDataCount();
    _notify();
  }

  Future<void> _updateSharingDataCount() async {
    final revision = ++_textRevision;
    sharingDataCount = null;
    try {
      final count = await transfers.service.sharingDataCount(
        text.text,
        pending: transfers.pending,
      );
      if (!_disposed && revision == _textRevision) {
        sharingDataCount = count;
        _notify();
      }
    } catch (_) {
      // Invalid or unresolved drafts cannot promise data links in a share.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void closePage(BuildContext context) {
    Navigator.of(context).pop();
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
      if (_disposed) transfers.dispose();
      _changed();
    }
  }

  RawEditorDraft get draft => RawEditorDraft(
    original: _draft!.original,
    name: name.text,
    text: text.text,
  );

  Future<void> test(BuildContext context) async {
    if (!canTest) return;
    final revision = _textRevision;
    busy = true;
    action = RawEditorAction.test;
    error = null;
    testResult = null;
    _notify();
    try {
      final result = await service.test(draft, geodata: transfers.pending);
      if (!_disposed && revision == _textRevision) testResult = result;
    } catch (_) {
      if (context.mounted && revision == _textRevision) {
        error = AppLocalizations.of(context)!.prototypeCheckNetwork;
      }
    } finally {
      busy = false;
      action = null;
      if (_disposed) transfers.dispose();
      _notify();
    }
  }

  Future<void> save(BuildContext context) async {
    if (!canSave) return;
    busy = true;
    action = RawEditorAction.save;
    error = null;
    _changed();
    final l10n = AppLocalizations.of(context)!;
    try {
      final id = await service.save(
        draft,
        geodata: transfers.pending,
        confirmReconnect: () => context.mounted
            ? ContextAlert.showConfirmDialog(
                context,
                title: l10n.prototypeApplyChange,
                content: l10n.prototypeReconnectNotice,
                confirmLabel: l10n.prototypeApplyAndReconnect,
              )
            : Future.value(false),
      );
      if (id != null &&
          !_disposed &&
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(id);
      }
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
      action = null;
      if (_disposed) transfers.dispose();
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (!busy) transfers.dispose();
    name.dispose();
    text.dispose();
    super.dispose();
  }
}
