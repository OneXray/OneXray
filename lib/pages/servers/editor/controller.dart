import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/assets/server.dart';

class ServerEditorController extends ChangeNotifier {
  final int serverId;
  final ServerAssetService service;
  ServerEditorController(this.serverId, {ServerAssetService? service})
    : service = service ?? ServerAssetService() {
    text.addListener(_changed);
  }
  final text = TextEditingController();
  ServerEditDraft? _draft;
  bool busy = true;
  String? error;
  bool _disposed = false;
  bool get loaded => _draft != null;
  String? get name => _draft?.original.name;
  bool get fromSubscription => _draft != null && _draft!.original.subId != 0;
  int get lineCount => '\n'.allMatches(text.text).length + 1;
  bool get validJson {
    try {
      final value = jsonDecode(text.text);
      return value is Map &&
          value['tag'] is String &&
          (value['tag'] as String).trim().isNotEmpty &&
          value['protocol'] is String &&
          (value['protocol'] as String).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void close(BuildContext context) {
    if (!busy) Navigator.of(context).pop();
  }

  Future<void> load(BuildContext context) async {
    try {
      final draft = await service.load(serverId);
      if (_disposed) return;
      _draft = draft;
      text.text = draft.text;
    } catch (_) {
      if (context.mounted) {
        error = AppLocalizations.of(context)!.prototypeCannotReadContent;
      }
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> save(BuildContext context) async {
    if (busy || !loaded) return;
    final l = AppLocalizations.of(context)!;
    busy = true;
    error = null;
    _changed();
    try {
      final saved = await service.save(
        ServerEditDraft(_draft!.original, text.text),
        confirmReconnect: () => context.mounted
            ? ContextAlert.showConfirmDialog(
                context,
                title: l.prototypeApplyChange,
                content: l.prototypeReconnectNotice,
                confirmLabel: l.prototypeApplyAndReconnect,
              )
            : Future.value(false),
      );
      if (saved && context.mounted) Navigator.of(context).pop(serverId);
    } on FormatException {
      error = l.validationJsonInvalid;
    } catch (_) {
      error = l.buttonSaveFailed;
    } finally {
      busy = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    text.dispose();
    super.dispose();
  }
}
