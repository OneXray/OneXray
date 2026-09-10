import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/service/shared/failure.dart';
import 'package:onexray/service/servers/server.dart';
import 'package:re_editor/re_editor.dart';

@immutable
class ServerEditorPageState {
  const ServerEditorPageState({
    this.draft,
    this.jsonText = '',
    this.busy = false,
    this.loading = true,
    this.error,
  });

  final ServerEditDraft? draft;
  final String jsonText;
  final bool busy;
  final bool loading;
  final String? error;

  bool get loaded => draft != null;
  String? get name => draft?.original.name;
  bool get fromSubscription => draft != null && draft!.original.subId != 0;
  bool get validJson {
    try {
      final value = jsonDecode(jsonText);
      return value is Map &&
          value['tag'] is String &&
          (value['tag'] as String).trim().isNotEmpty &&
          value['protocol'] is String &&
          (value['protocol'] as String).trim().isNotEmpty;
    } catch (error) {
      return false;
    }
  }

  ServerEditorPageState copyWith({
    ServerEditDraft? draft,
    String? jsonText,
    bool? busy,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => ServerEditorPageState(
    draft: draft ?? this.draft,
    jsonText: jsonText ?? this.jsonText,
    busy: busy ?? this.busy,
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
  );
}

class ServerEditorController extends PageCubit<ServerEditorPageState> {
  ServerEditorController(this.serverId, {ServerAssetService? service})
    : service = service ?? ServerAssetService(),
      super(const ServerEditorPageState()) {
    text.addListener(_textChanged);
  }

  final int serverId;
  final ServerAssetService service;
  final text = CodeLineEditingController();

  void _textChanged() => emit(state.copyWith(jsonText: text.text));

  void closePage(BuildContext context) {
    if (!state.busy) Navigator.of(context).pop();
  }

  Future<void> load(BuildContext context) async {
    final initialText = text.text;
    try {
      final draft = await service.load(serverId);
      if (!isPageActive) return;
      emit(state.copyWith(draft: draft));
      if (text.text == initialText) text.text = draft.text;
    } catch (error) {
      if (context.mounted) {
        emit(
          state.copyWith(
            error: appFailureMessage(AppLocalizations.of(context)!, error),
          ),
        );
      }
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  Future<void> save(BuildContext context) async {
    if (state.busy || state.loading || !state.loaded) return;
    final l = AppLocalizations.of(context)!;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final saved = await service.save(
        ServerEditDraft(state.draft!.original, state.jsonText),
        confirmReconnect: () => isPageActive && context.mounted
            ? ContextAlert.showConfirmDialog(
                context,
                title: l.prototypeApplyChange,
                content: l.prototypeReconnectNotice,
                confirmLabel: l.prototypeApplyAndReconnect,
              )
            : Future.value(false),
      );
      if (saved && isPageActive && context.mounted) {
        ContextAlert.showToast(context, l.prototypeSettingsSaved);
        Navigator.of(context).pop(serverId);
      }
    } catch (error) {
      emit(
        state.copyWith(
          error: appFailureMessage(l, error, operation: l.buttonSaveFailed),
        ),
      );
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  @override
  void disposePageResources() {
    text.removeListener(_textChanged);
    text.dispose();
  }
}
