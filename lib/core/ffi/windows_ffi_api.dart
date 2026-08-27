import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/desktop_core_process.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

class WindowsFfiApi extends BaseFfiApi {
  static final WindowsFfiApi _singleton = WindowsFfiApi._internal();

  factory WindowsFfiApi() => _singleton;

  WindowsFfiApi._internal();

  static const _coreExe = "OneXrayCore.exe";

  final _processStore = DesktopCoreProcessStore();
  Process? _coreProcess;
  bool _stopping = false;

  @override
  Future<bool> startCore(LibXrayRunConfig request) async {
    if (!await _stopCoreProcess()) {
      ygLogger("start core failed: previous core is still running");
      return false;
    }

    try {
      final configPath = await materializeRunXrayConfig(request);
      if (configPath == null) {
        ygLogger("start core failed: xrayJson is empty");
        return false;
      }
      final command = <String>[corePath, "run", "-config", configPath];
      ygLogger("Running command: ${command.join(" ")}");
      final process = await Process.start(command.first, command.sublist(1));
      _coreProcess = process;
      _bindProcess(process);
      _trackProcess(process);
      await _processStore.write(DesktopCoreProcessRecord(pid: process.pid));
      ygLogger("core process started with pid: ${process.pid}");
    } catch (error) {
      ygLogger("start core failed: $error");
      await _stopCoreProcess();
      return false;
    }

    await Future.delayed(const Duration(seconds: 1));
    return await queryCoreRunning() ?? false;
  }

  Future<bool> cleanupStaleCore() async {
    if (_coreProcess != null) {
      return true;
    }
    return _stopCoreProcessesByName();
  }

  @override
  Future<bool> stopCore() => _stopCoreProcess();

  @override
  Future<bool?> queryCoreRunning() async {
    final process = _coreProcess;
    if (process == null) {
      return false;
    }
    final record = await _processStore.read();
    return identical(_coreProcess, process) && record?.pid == process.pid;
  }

  Future<bool> _stopCoreProcess() async {
    final process = _coreProcess;
    if (process == null) {
      return _stopCoreProcessesByName();
    }

    _stopping = true;
    try {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        final result = await Process.run('taskkill.exe', <String>[
          '/PID',
          '${process.pid}',
          '/T',
          '/F',
        ]);
        if (result.exitCode != 0) {
          ygLogger(
            'stop core process failed. exitCode=${result.exitCode} '
            'stderr=${result.stderr}',
          );
          return false;
        }
        try {
          await process.exitCode.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          return false;
        }
      }
      if (identical(_coreProcess, process)) {
        _coreProcess = null;
      }
      await _processStore.clear(pid: process.pid);
      return true;
    } finally {
      _stopping = false;
    }
  }

  Future<bool> _stopCoreProcessesByName() async {
    final sessionId = _currentSessionId();
    if (sessionId == null) {
      return false;
    }
    final running = await _coreProcessesRunning(sessionId);
    if (running == null) {
      return false;
    }
    if (!running) {
      await _processStore.clear();
      return true;
    }

    try {
      final result = await Process.run('taskkill.exe', <String>[
        '/F',
        '/T',
        '/FI',
        'SESSION eq $sessionId',
        '/IM',
        _coreExe,
      ]);
      if (result.exitCode != 0) {
        ygLogger(
          'stop core processes failed. exitCode=${result.exitCode} '
          'stderr=${result.stderr}',
        );
        return false;
      }
    } catch (error) {
      ygLogger('stop core processes failed: $error');
      return false;
    }

    if (!await _waitForCoreProcessesExit(
      sessionId,
      const Duration(seconds: 3),
    )) {
      return false;
    }
    await _processStore.clear();
    return true;
  }

  Future<bool?> _coreProcessesRunning(int sessionId) async {
    try {
      final result = await Process.run('tasklist.exe', <String>[
        '/FI',
        'IMAGENAME eq $_coreExe',
        '/FI',
        'SESSION eq $sessionId',
        '/NH',
      ]);
      if (result.exitCode != 0) {
        ygLogger(
          'find core processes failed. exitCode=${result.exitCode} '
          'stderr=${result.stderr}',
        );
        return null;
      }
      final coreExe = _coreExe.toLowerCase();
      return result.stdout
          .toString()
          .split('\n')
          .map((line) => line.trim().toLowerCase())
          .any((line) => line.startsWith(coreExe));
    } catch (error) {
      ygLogger('find core processes failed: $error');
      return null;
    }
  }

  Future<bool> _waitForCoreProcessesExit(
    int sessionId,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final running = await _coreProcessesRunning(sessionId);
      if (running == null) {
        return false;
      }
      if (!running) {
        return true;
      }
      if (DateTime.now().isAfter(deadline)) {
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  int? _currentSessionId() {
    final sessionId = calloc<Uint32>();
    try {
      final result = ProcessIdToSessionId(GetCurrentProcessId(), sessionId);
      if (!result.value) {
        ygLogger(
          'read current Windows session id failed. errorCode=${result.error}',
        );
        return null;
      }
      return sessionId.value;
    } finally {
      free(sessionId);
    }
  }

  String get corePath {
    final bundleDir = p.dirname(Platform.resolvedExecutable);
    return p.join(bundleDir, "bin", _coreExe);
  }

  void _bindProcess(Process process) {
    process.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((
      output,
    ) {
      if (output.trim().isNotEmpty) {
        ygLogger(output.trim());
      }
    });
    process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((
      output,
    ) {
      if (output.trim().isNotEmpty) {
        ygLogger(output.trim());
      }
    });
  }

  void _trackProcess(Process process) {
    process.exitCode.then((_) {
      if (!identical(_coreProcess, process)) {
        return;
      }
      _coreProcess = null;
      unawaited(_processStore.clear(pid: process.pid));
      if (!_stopping) {
        unawaited(updateVpnStatus(VpnStatus.disconnected));
      }
    });
  }
}
