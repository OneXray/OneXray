import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/xray/runtime_files.dart';
import 'package:path/path.dart' as p;

import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';

class LogFileViewerPageState {
  final String title;
  final List<String> lines;
  final bool fileExists;
  final bool followTail;
  final bool truncated;
  final bool exporting;

  const LogFileViewerPageState({
    this.title = "",
    this.lines = const [],
    this.fileExists = false,
    this.followTail = true,
    this.truncated = false,
    this.exporting = false,
  });

  LogFileViewerPageState copyWith({
    String? title,
    List<String>? lines,
    bool? fileExists,
    bool? followTail,
    bool? truncated,
    bool? exporting,
  }) {
    return LogFileViewerPageState(
      title: title ?? this.title,
      lines: lines ?? this.lines,
      fileExists: fileExists ?? this.fileExists,
      followTail: followTail ?? this.followTail,
      truncated: truncated ?? this.truncated,
      exporting: exporting ?? this.exporting,
    );
  }
}

class LogFileViewerController extends PageCubit<LogFileViewerPageState> {
  static const int _maxBufferBytes = 1024 * 1024;
  static const Duration _pollInterval = Duration(seconds: 1);

  final LogFileViewerParams params;

  Timer? _timer;
  int _offset = 0;
  String? _fileId;
  var _droppedContent = false;
  var _reading = false;
  List<int> _buffer = const [];

  LogFileViewerController(this.params)
    : super(LogFileViewerPageState(title: params.title)) {
    _poll();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_reading || !isPageActive) return;
    _reading = true;
    try {
      var chunk = await RuntimeDiagnosticFiles.readLog(
        params.path,
        planId: params.systemExtensionPlanId,
        access: params.access,
        offset: _fileId == null ? -1 : _offset,
      );
      var replace = _fileId == null;
      if (chunk != null &&
          !replace &&
          (chunk.fileId != _fileId ||
              chunk.size < _offset ||
              chunk.size - _offset > _maxBufferBytes)) {
        chunk = await RuntimeDiagnosticFiles.readLog(
          params.path,
          planId: params.systemExtensionPlanId,
          access: params.access,
        );
        replace = true;
      }
      if (chunk == null) {
        _resetMissingFile();
        return;
      }
      if (replace) {
        _droppedContent = chunk.offset > 0;
        _buffer = chunk.offset > 0
            ? _dropPartialFirstLine(chunk.data)
            : chunk.data;
      } else {
        _buffer = _trimBuffer([..._buffer, ...chunk.data]);
      }
      _offset = chunk.offset + chunk.data.length;
      _fileId = chunk.fileId;
      _emitBuffer(
        fileExists: true,
        truncated: replace ? _droppedContent : state.truncated,
      );
    } catch (_) {
      // Unavailable provider messages must not leave a stale successful view.
      _resetMissingFile();
    } finally {
      _reading = false;
    }
  }

  List<int> _trimBuffer(List<int> bytes) {
    if (bytes.length <= _maxBufferBytes) {
      return bytes;
    }
    _droppedContent = true;
    return _dropPartialFirstLine(bytes.sublist(bytes.length - _maxBufferBytes));
  }

  List<int> _dropPartialFirstLine(List<int> bytes) {
    final newlineIndex = bytes.indexOf(0x0a);
    if (newlineIndex < 0) {
      return const [];
    }
    if (newlineIndex + 1 >= bytes.length) {
      return const [];
    }
    return bytes.sublist(newlineIndex + 1);
  }

  void _emitBuffer({required bool fileExists, required bool truncated}) {
    if (!isPageActive) {
      return;
    }
    final text = utf8.decode(_buffer, allowMalformed: true);
    final lines = text.isEmpty
        ? const <String>[]
        : const LineSplitter().convert(text);
    emit(
      state.copyWith(
        lines: lines,
        fileExists: fileExists,
        truncated: truncated || _droppedContent,
      ),
    );
  }

  void _resetMissingFile() {
    _offset = 0;
    _fileId = null;
    _droppedContent = false;
    _buffer = const [];
    _emitBuffer(fileExists: false, truncated: false);
  }

  void setFollowTail(bool value) {
    if (state.followTail == value) {
      return;
    }
    emit(state.copyWith(followTail: value));
  }

  Future<void> export(BuildContext context) async {
    if (state.exporting || !state.fileExists) return;
    final l = AppLocalizations.of(context)!;
    emit(state.copyWith(exporting: true));
    try {
      final confirmed = await AppConfirmationDialog(
        title: l.prototypeExport,
        subject: p.basename(params.path),
        content: l.prototypeLocalLogNotice,
        cancelLabel: l.prototypeCancel,
        confirmLabel: l.prototypeExport,
      ).show(context);
      if (confirmed != true || !isPageActive) return;
      await RuntimeDiagnosticFiles.exportLog(
        params.path,
        p.basename(params.path),
        planId: params.systemExtensionPlanId,
        access: params.access,
      );
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

  @override
  Future<void> disposePageResources() async {
    _timer?.cancel();
  }
}
