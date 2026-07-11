import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/desktop_core_process.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as p;
import 'package:process/process.dart';

class LinuxFfiApi extends BaseFfiApi {
  static final LinuxFfiApi _singleton = LinuxFfiApi._internal();

  factory LinuxFfiApi() => _singleton;

  LinuxFfiApi._internal();

  //===================================
  static const _coreBin = "OneXrayCore";
  static const _stopProxyCoreFailed = "stop proxy core failed";
  final _processManager = LocalProcessManager();
  final _processStore = DesktopCoreProcessStore();
  Process? _coreProcess;
  bool _stopping = false;

  @override
  Future<bool> startCore(LibXrayRunConfig request) async {
    return _startCore(request);
  }

  Future<bool> _startCore(LibXrayRunConfig request) async {
    try {
      final configPath = request.request.configPath;
      if (configPath == null || configPath.isEmpty) {
        ygLogger("start core failed: config path is empty");
        return false;
      }

      if (!await _stopCoreProcess()) {
        ygLogger("start core failed: previous core is still running");
        return false;
      }

      final command = <String>[corePath, "run", "-config", configPath];
      ygLogger("Running command: ${command.join(" ")}");
      final process = await _processManager.start(command);
      _bindProcess(process);
      _coreProcess = process;
      _trackProcess(process);
      await _processStore.write(
        DesktopCoreProcessRecord(pid: process.pid, executablePath: corePath),
      );
    } catch (e) {
      ygLogger("start core failed: $e");
      await _stopCoreProcess();
      return false;
    }

    await Future.delayed(Duration(seconds: 1));

    return await queryCoreRunning() ?? false;
  }

  Future<bool> startProxyCore(LibXrayRunConfig request) async {
    return _startCore(request);
  }

  Future<bool> cleanupStaleCore() async {
    if (_coreProcess != null) {
      return true;
    }
    final record = await _processStore.read();
    if (record == null) {
      return true;
    }
    return _stopRecordedCore(record);
  }

  @override
  Future<bool> stopCore() => _stopCoreProcess();

  Future<String> stopProxyCore() async {
    final stopped = await _stopProxyCore();
    return stopped ? "" : _stopProxyCoreFailed;
  }

  Future<bool> proxyCoreRunning() async => await queryCoreRunning() ?? false;

  Future<bool> _stopProxyCore() async {
    return _stopCoreProcess();
  }

  Future<bool> _stopCoreProcess() async {
    final process = _coreProcess;
    if (process != null) {
      return _stopCurrentCore(process);
    }
    final record = await _processStore.read();
    return record == null ? true : _stopRecordedCore(record);
  }

  Future<bool> _stopCurrentCore(Process process) async {
    _stopping = true;
    try {
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(Duration(seconds: 3));
      } on TimeoutException {
        if (!process.kill(ProcessSignal.sigkill)) {
          return false;
        }
        try {
          await process.exitCode.timeout(Duration(seconds: 2));
        } on TimeoutException {
          return false;
        }
      }
      _coreProcess = null;
      await _processStore.clear(pid: process.pid);
      return true;
    } finally {
      _stopping = false;
    }
  }

  Future<bool> _stopRecordedCore(DesktopCoreProcessRecord record) async {
    if (!await _recordIsRunning(record)) {
      await _processStore.clear(pid: record.pid);
      return true;
    }

    final terminated = Process.killPid(record.pid, ProcessSignal.sigterm);
    if (!terminated && await _recordIsRunning(record)) {
      return false;
    }
    try {
      await _waitForRecordedCoreExit(record, Duration(seconds: 3));
    } on TimeoutException {
      final killed = Process.killPid(record.pid, ProcessSignal.sigkill);
      if (!killed && await _recordIsRunning(record)) {
        return false;
      }
      try {
        await _waitForRecordedCoreExit(record, Duration(seconds: 2));
      } on TimeoutException {
        return false;
      }
    }
    await _processStore.clear(pid: record.pid);
    return true;
  }

  @override
  Future<bool?> queryCoreRunning() async {
    final process = _coreProcess;
    if (process == null) {
      return false;
    }
    final record = await _processStore.read();
    return record != null &&
        record.pid == process.pid &&
        await _recordIsRunning(record);
  }

  Future<bool> _recordIsRunning(DesktopCoreProcessRecord record) async {
    try {
      final executable = await Link('/proc/${record.pid}/exe').target();
      return linuxExecutableMatches(executable, record.executablePath);
    } catch (_) {
      return false;
    }
  }

  Future<void> _waitForRecordedCoreExit(
    DesktopCoreProcessRecord record,
    Duration timeout,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (await _recordIsRunning(record)) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('core process did not exit', timeout);
      }
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  String get corePath {
    if (kReleaseMode) {
      final bundleDir = p.dirname(Platform.resolvedExecutable);
      final corePath = p.join(bundleDir, "bin", _coreBin);
      return corePath;
    } else {
      final homeDir = Platform.environment["HOME"];
      if (homeDir == null) {
        return _coreBin;
      }
      return p.join(homeDir, "work", "vpn", _coreBin);
    }
  }

  void _bindProcess(Process process) {
    process.stdout.listen((data) {
      if (!kReleaseMode) {
        ygLogger(utf8.decode(data));
      }
    });
    process.stderr.listen((data) {
      if (!kReleaseMode) {
        ygLogger(utf8.decode(data));
      }
    });
  }

  void _trackProcess(Process process) {
    process.exitCode.then((_) {
      if (identical(_coreProcess, process)) {
        _coreProcess = null;
        unawaited(_processStore.clear(pid: process.pid));
        if (!_stopping) {
          unawaited(updateVpnStatus(VpnStatus.disconnected));
        }
      }
    });
  }
}
