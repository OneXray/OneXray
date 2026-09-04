import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/widget/configuration_transfer.dart';
import 'package:onexray/service/assets/raw_editor.dart';
import 'package:onexray/service/share/configuration_transfer.dart';
import 'package:re_editor/re_editor.dart';

enum RawEditorAction { test, save }

const _unchanged = Object();

class RawEditorPageState {
  final bool loaded;
  final bool busy;
  final RawEditorAction? action;
  final String? error;
  final RawTestResult? testResult;
  final int? sharingDataCount;
  final String name;
  final String text;
  final ConfigurationTransferState transfer;

  const RawEditorPageState({
    this.loaded = false,
    this.busy = true,
    this.action,
    this.error,
    this.testResult,
    this.sharingDataCount,
    this.name = '',
    this.text = '',
    this.transfer = const ConfigurationTransferState(),
  });

  RawEditorPageState copyWith({
    bool? loaded,
    bool? busy,
    Object? action = _unchanged,
    Object? error = _unchanged,
    Object? testResult = _unchanged,
    Object? sharingDataCount = _unchanged,
    String? name,
    String? text,
    ConfigurationTransferState? transfer,
  }) => RawEditorPageState(
    loaded: loaded ?? this.loaded,
    busy: busy ?? this.busy,
    action: identical(action, _unchanged)
        ? this.action
        : action as RawEditorAction?,
    error: identical(error, _unchanged) ? this.error : error as String?,
    testResult: identical(testResult, _unchanged)
        ? this.testResult
        : testResult as RawTestResult?,
    sharingDataCount: identical(sharingDataCount, _unchanged)
        ? this.sharingDataCount
        : sharingDataCount as int?,
    name: name ?? this.name,
    text: text ?? this.text,
    transfer: transfer ?? this.transfer,
  );
}

class RawEditorController extends PageCubit<RawEditorPageState> {
  final RawEditorService service;
  final int? rawId;
  final String? initialText;
  final String? initialName;

  RawEditorController({
    required this.rawId,
    this.initialText,
    this.initialName,
    RawEditorService? service,
  }) : service = service ?? RawEditorService(),
       super(const RawEditorPageState()) {
    text.addListener(_textChanged);
    name.addListener(_nameChanged);
    _transferSubscription = transfers.stream.listen(_transferChanged);
  }

  final name = TextEditingController();
  final text = CodeLineEditingController();
  RawEditorDraft? _draft;
  bool _saving = false;
  int _textRevision = 0;
  late final StreamSubscription<ConfigurationTransferState>
  _transferSubscription;
  late final transfers = ConfigurationTransferController(
    kind: ConfigurationKind.raw,
    readText: () => text.text,
    readName: () => name.text,
    onImport: (draft) {
      text.text = draft.text;
      if (name.text.trim().isEmpty && draft.name.isNotEmpty) {
        name.text = draft.name;
      }
      emit(state.copyWith(error: null));
    },
  );

  bool get busy => state.busy;
  RawEditorAction? get action => state.action;
  String? get error => state.error;
  RawTestResult? get testResult => state.testResult;
  int? get sharingDataCount => state.sharingDataCount;
  bool get working => state.busy || state.transfer.busy;
  bool get loaded => state.loaded;
  bool get canTest => !working && loaded && state.text.trim().isNotEmpty;
  bool get canSave => canTest && state.name.trim().isNotEmpty;

  void _textChanged() {
    if (!isPageActive) return;
    emit(state.copyWith(text: text.text, testResult: null));
    unawaited(_updateSharingDataCount());
  }

  void _nameChanged() {
    if (isPageActive && state.name != name.text) {
      emit(state.copyWith(name: name.text));
    }
  }

  void _transferChanged(ConfigurationTransferState transfer) {
    if (!isPageActive) return;
    emit(state.copyWith(transfer: transfer));
    unawaited(_updateSharingDataCount());
  }

  Future<void> _updateSharingDataCount() async {
    final revision = ++_textRevision;
    emit(state.copyWith(sharingDataCount: null));
    try {
      final count = await transfers.service.sharingDataCount(
        state.text,
        pending: transfers.pending,
      );
      if (isPageActive && revision == _textRevision) {
        emit(state.copyWith(sharingDataCount: count));
      }
    } catch (_) {
      // Invalid or unresolved drafts cannot promise data links in a share.
    }
  }

  void closePage(BuildContext context) => Navigator.of(context).pop();

  Future<void> load(BuildContext context) async {
    try {
      final draft = await service.load(rawId);
      if (!isPageActive) return;
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
        emit(
          state.copyWith(
            error: AppLocalizations.of(context)!.prototypeCannotReadContent,
          ),
        );
      }
    } finally {
      if (isPageActive) {
        emit(
          state.copyWith(
            loaded: _draft != null,
            busy: false,
            name: name.text,
            text: text.text,
          ),
        );
      }
    }
  }

  RawEditorDraft get draft => RawEditorDraft(
    original: _draft!.original,
    name: state.name,
    text: state.text,
  );

  Future<void> test(BuildContext context) async {
    if (!canTest) return;
    final revision = _textRevision;
    emit(
      state.copyWith(
        busy: true,
        action: RawEditorAction.test,
        error: null,
        testResult: null,
      ),
    );
    try {
      final result = await service.test(draft);
      if (isPageActive && revision == _textRevision) {
        emit(state.copyWith(testResult: result));
      }
    } catch (_) {
      if (context.mounted && revision == _textRevision) {
        emit(
          state.copyWith(
            error: AppLocalizations.of(context)!.prototypeCheckNetwork,
          ),
        );
      }
    } finally {
      emit(state.copyWith(busy: false, action: null));
    }
  }

  Future<void> save(BuildContext context) async {
    if (!canSave) return;
    _saving = true;
    emit(state.copyWith(busy: true, action: RawEditorAction.save, error: null));
    final l10n = AppLocalizations.of(context)!;
    try {
      final id = await service.save(
        draft,
        geodata: transfers.pending,
        confirmReconnect: () => context.mounted
            ? showApplyAndReconnectDialog(context, label: state.name.trim())
            : Future.value(false),
      );
      if (id != null &&
          isPageActive &&
          context.mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(id);
      }
    } on RawEditorException catch (failure) {
      emit(
        state.copyWith(
          error: switch (failure.reason) {
            'limit' => l10n.prototypeRawJsonLimit,
            'name' => l10n.validationNameRequired,
            'invalid' => l10n.validationJsonInvalid,
            _ => l10n.buttonSaveFailed,
          },
        ),
      );
    } on FormatException {
      emit(state.copyWith(error: l10n.validationJsonInvalid));
    } catch (_) {
      emit(state.copyWith(error: l10n.buttonSaveFailed));
    } finally {
      _saving = false;
      if (!isPageActive) await transfers.close();
      emit(state.copyWith(busy: false, action: null));
    }
  }

  @override
  Future<void> disposePageResources() async {
    text.removeListener(_textChanged);
    name.removeListener(_nameChanged);
    await _transferSubscription.cancel();
    if (!_saving) await transfers.close();
    name.dispose();
    text.dispose();
  }
}
