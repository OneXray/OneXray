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
  Timer? _processMonitor;
  bool _stopping = false;

  @override
  Future<bool> startCore(LibXrayRunConfig request) async {
    return _startCore(request, DesktopCoreMode.tun);
  }

  Future<bool> _startCore(
    LibXrayRunConfig request,
    DesktopCoreMode mode,
  ) async {
    try {
      final configPath = request.request.configPath;
      if (configPath == null || configPath.isEmpty) {
        ygLogger("start core failed: config path is empty");
        return false;
      }

      if (!await _stopOwnedCore()) {
        ygLogger("start core failed: previous owned core is still running");
        return false;
      }

      final command = <String>[corePath, "run", "-config", configPath];
      ygLogger("Running command: ${command.join(" ")}");
      final process = await _processManager.start(command);
      _bindProcess(process);
      _coreProcess = process;
      _trackProcess(process);
      await _processStore.write(
        DesktopCoreProcessRecord(
          pid: process.pid,
          executablePath: corePath,
          mode: mode,
        ),
      );
    } catch (e) {
      ygLogger("start core failed: $e");
      await _stopOwnedCore();
      return false;
    }

    await Future.delayed(Duration(seconds: 1));

    return await queryCoreRunning() ?? false;
  }

  Future<bool> startProxyCore(LibXrayRunConfig request) async {
    return _startCore(request, DesktopCoreMode.proxy);
  }

  @override
  Future<void> stopCore() async {
    await _stopOwnedCore();
  }

  Future<String> stopProxyCore() async {
    final stopped = await _stopProxyCore();
    return stopped ? "" : _stopProxyCoreFailed;
  }

  Future<bool> proxyCoreRunning() async => await queryCoreRunning() ?? false;

  Future<bool> _stopProxyCore() async {
    return _stopOwnedCore();
  }

  Future<bool> _stopOwnedCore() async {
    _processMonitor?.cancel();
    _processMonitor = null;
    final process = _coreProcess;
    final record = await _processStore.read();
    if (process == null && record == null) {
      return true;
    }

    final pid = process?.pid ?? record!.pid;
    if (record != null && !await _recordIsRunning(record)) {
      await _processStore.clear(pid: record.pid);
      return true;
    }

    _stopping = true;
    try {
      final terminated =
          process?.kill(ProcessSignal.sigterm) ??
          Process.killPid(pid, ProcessSignal.sigterm);
      if (!terminated && await _pidIsRunning(pid)) {
        return false;
      }
      await _waitForPidExit(pid, Duration(seconds: 3));
      _coreProcess = null;
      await _processStore.clear(pid: pid);
      return true;
    } on TimeoutException {
      final killed = Process.killPid(pid, ProcessSignal.sigkill);
      if (!killed) {
        return false;
      }
      try {
        await _waitForPidExit(pid, Duration(seconds: 2));
        _coreProcess = null;
        await _processStore.clear(pid: pid);
        return true;
      } on TimeoutException {
        return false;
      }
    } finally {
      _stopping = false;
    }
  }

  @override
  Future<bool?> queryCoreRunning() async {
    final process = _coreProcess;
    if (process != null) {
      return _pidIsRunning(process.pid);
    }
    final record = await _processStore.read();
    if (record == null) {
      return false;
    }
    final running = await _recordIsRunning(record);
    if (!running) {
      await _processStore.clear(pid: record.pid);
    } else if (_coreProcess == null) {
      _startProcessMonitor(record);
    }
    return running;
  }

  Future<bool> _recordIsRunning(DesktopCoreProcessRecord record) async {
    if (p.normalize(record.executablePath) != p.normalize(corePath)) {
      return false;
    }
    try {
      final executable = await File(
        '/proc/${record.pid}/exe',
      ).resolveSymbolicLinks();
      return p.normalize(executable) == p.normalize(corePath);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _pidIsRunning(int pid) async {
    final record = await _processStore.read();
    if (record == null || record.pid != pid) {
      return false;
    }
    return _recordIsRunning(record);
  }

  Future<void> _waitForPidExit(int pid, Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (await _pidIsRunning(pid)) {
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

  void _startProcessMonitor(DesktopCoreProcessRecord record) {
    _processMonitor?.cancel();
    _processMonitor = Timer.periodic(Duration(seconds: 1), (_) async {
      if (_stopping || await _recordIsRunning(record)) {
        return;
      }
      _processMonitor?.cancel();
      _processMonitor = null;
      await _processStore.clear(pid: record.pid);
      await updateVpnStatus(VpnStatus.disconnected);
    });
  }
}
