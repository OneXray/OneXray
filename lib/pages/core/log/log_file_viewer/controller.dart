import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';

class LogFileViewerPageState {
  final String title;
  final List<String> lines;
  final bool fileExists;
  final bool followTail;
  final bool truncated;

  const LogFileViewerPageState({
    this.title = "",
    this.lines = const [],
    this.fileExists = false,
    this.followTail = true,
    this.truncated = false,
  });

  LogFileViewerPageState copyWith({
    String? title,
    List<String>? lines,
    bool? fileExists,
    bool? followTail,
    bool? truncated,
  }) {
    return LogFileViewerPageState(
      title: title ?? this.title,
      lines: lines ?? this.lines,
      fileExists: fileExists ?? this.fileExists,
      followTail: followTail ?? this.followTail,
      truncated: truncated ?? this.truncated,
    );
  }
}

class LogFileViewerController extends PageCubit<LogFileViewerPageState> {
  static const int _maxBufferBytes = 1024 * 1024;
  static const Duration _pollInterval = Duration(seconds: 1);

  final LogFileViewerParams params;

  Timer? _timer;
  int _offset = 0;
  var _droppedContent = false;
  List<int> _buffer = const [];

  LogFileViewerController(this.params)
    : super(LogFileViewerPageState(title: params.title)) {
    _loadTail();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _loadTail() async {
    try {
      final file = File(params.path);
      if (!await file.exists()) {
        _resetMissingFile();
        return;
      }

      final length = await file.length();
      var start = length > _maxBufferBytes ? length - _maxBufferBytes : 0;
      var bytes = await _readRange(file, start, length);
      final truncated = start > 0;
      _droppedContent = truncated;
      if (truncated) {
        bytes = _dropPartialFirstLine(bytes);
      }
      _offset = length;
      _buffer = _trimBuffer(bytes);
      _emitBuffer(fileExists: true, truncated: truncated);
    } on FileSystemException {
      _resetMissingFile();
    }
  }

  Future<void> _poll() async {
    try {
      final file = File(params.path);
      if (!await file.exists()) {
        _resetMissingFile();
        return;
      }

      final length = await file.length();
      if (length < _offset) {
        await _loadTail();
        return;
      }
      if (length == _offset) {
        return;
      }

      final bytes = await _readRange(file, _offset, length);
      _offset = length;
      _buffer = _trimBuffer([..._buffer, ...bytes]);
      _emitBuffer(fileExists: true, truncated: state.truncated);
    } on FileSystemException {
      _resetMissingFile();
    }
  }

  Future<List<int>> _readRange(File file, int start, int end) async {
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      return await raf.read(end - start);
    } finally {
      await raf.close();
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

  @override
  Future<void> disposePageResources() async {
    _timer?.cancel();
  }
}
