import 'dart:async';

import 'package:onexray/core/errors/json_diagnostic.dart';
import 'package:onexray/core/tools/json_document.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/service/shared/json_editing.dart';
import 'package:re_editor/re_editor.dart';

class JsonEditorState {
  const JsonEditorState({
    this.diagnostic,
    this.range,
    this.completions = const [],
    this.selectedCompletion = 0,
  });

  final JsonDiagnostic? diagnostic;
  final JsonSourceRange? range;
  final List<JsonCompletion> completions;
  final int selectedCompletion;
}

/// UI state for an editor draft. Only local JSON parsing runs while typing;
/// the owning page remains responsible for explicit save/Core validation.
class JsonEditorCubit extends PageCubit<JsonEditorState> {
  JsonEditorCubit({
    required this.controller,
    required this._kind,
    required this._domainSuggestions,
    required this._ipSuggestions,
    JsonDiagnostic? diagnostic,
  }) : _text = controller.text,
       super(const JsonEditorState()) {
    controller.addListener(_editingChanged);
    updateDiagnostic(diagnostic);
    _scheduleSyntaxCheck();
  }

  final CodeLineEditingController controller;
  JsonEditorKind? _kind;
  List<String> _domainSuggestions;
  List<String> _ipSuggestions;
  String _text;
  JsonDocument? _document;
  JsonDiagnostic? _externalDiagnostic;
  JsonDiagnostic? _syntaxDiagnostic;
  Timer? _syntaxTimer;
  bool _focused = false;

  JsonDocument get document => _document ??= JsonDocument(_text);

  void configure({
    required JsonEditorKind? kind,
    required List<String> domainSuggestions,
    required List<String> ipSuggestions,
  }) {
    _kind = kind;
    _domainSuggestions = domainSuggestions;
    _ipSuggestions = ipSuggestions;
    _updateCompletions();
  }

  void updateDiagnostic(JsonDiagnostic? diagnostic) {
    _externalDiagnostic = diagnostic;
    _publishDiagnostic();
  }

  void setFocused(bool focused) {
    _focused = focused;
    _updateCompletions();
  }

  void _editingChanged() {
    final text = controller.text;
    if (text != _text) {
      _text = text;
      _document = null;
      _externalDiagnostic = null;
      _syntaxDiagnostic = null;
      emit(const JsonEditorState());
      _scheduleSyntaxCheck();
    }
    _updateCompletions();
  }

  void _scheduleSyntaxCheck() {
    _syntaxTimer?.cancel();
    _syntaxTimer = Timer(const Duration(milliseconds: 300), () {
      if (!isPageActive) return;
      _syntaxDiagnostic = _text.trim().isEmpty ? null : document.syntaxError;
      _publishDiagnostic();
    });
  }

  void _publishDiagnostic() {
    final diagnostic = _externalDiagnostic ?? _syntaxDiagnostic;
    emit(
      JsonEditorState(
        diagnostic: diagnostic,
        range: diagnostic == null
            ? null
            : document.rangeForDiagnostic(diagnostic),
        completions: state.completions,
        selectedCompletion: state.selectedCompletion,
      ),
    );
  }

  void _updateCompletions() {
    final kind = _kind;
    final selection = controller.selection;
    final completions =
        !_focused ||
            kind == null ||
            !selection.isCollapsed ||
            controller.isComposing
        ? const <JsonCompletion>[]
        : JsonEditing.complete(
            _text,
            document.offsetAt(selection.extentIndex, selection.extentOffset),
            kind,
            domainSuggestions: _domainSuggestions,
            ipSuggestions: _ipSuggestions,
          );
    emit(
      JsonEditorState(
        diagnostic: state.diagnostic,
        range: state.range,
        completions: completions,
      ),
    );
  }

  void selectCompletion(int delta) {
    if (state.completions.isEmpty) return;
    emit(
      JsonEditorState(
        diagnostic: state.diagnostic,
        range: state.range,
        completions: state.completions,
        selectedCompletion:
            (state.selectedCompletion + delta) % state.completions.length,
      ),
    );
  }

  void dismissCompletions() {
    emit(JsonEditorState(diagnostic: state.diagnostic, range: state.range));
  }

  void applyCompletion([int? index]) {
    if (state.completions.isEmpty || controller.isComposing) return;
    final completion = state.completions[index ?? state.selectedCompletion];
    controller.replaceSelection(
      completion.insertText,
      selectionFor(JsonSourceRange(completion.start, completion.end)),
    );
    dismissCompletions();
  }

  CodeLineSelection selectionFor(JsonSourceRange range) {
    final start = document.positionAt(range.start);
    final end = document.positionAt(range.end);
    return CodeLineSelection(
      baseIndex: start.line,
      baseOffset: start.column,
      extentIndex: end.line,
      extentOffset: end.column,
    );
  }

  @override
  void disposePageResources() {
    _syntaxTimer?.cancel();
    controller.removeListener(_editingChanged);
  }
}
