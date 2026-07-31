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
  Future<String?>? _effectiveUserIdFuture;
  Process? _coreProcess;
  bool _stopping = false;

  @override
  Future<bool> startCore(LibXrayRunConfig request) async {
    return _startCore(request);
  }

  Future<bool> _startCore(LibXrayRunConfig request) async {
    try {
      if (!await _stopCoreProcess()) {
        ygLogger("start core failed: previous core is still running");
        return false;
      }

      final configPath = await materializeRunXrayConfig(request);
      if (configPath == null) {
        ygLogger("start core failed: xrayJson is empty");
        return false;
      }

      final command = <String>[corePath, "run", "-config", configPath];
      ygLogger("Running command: ${command.join(" ")}");
      final process = await _processManager.start(command);
      _bindProcess(process);
      _coreProcess = process;
      _trackProcess(process);
      await _processStore.write(DesktopCoreProcessRecord(pid: process.pid));
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
    return _stopCoreProcessesByName();
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
    return _stopCoreProcessesByName();
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

  @override
  Future<bool?> queryCoreRunning() async {
    final process = _coreProcess;
    if (process == null) {
      return false;
    }
    final record = await _processStore.read();
    return record != null &&
        record.pid == process.pid &&
        await _coreProcessIsRunning(process.pid);
  }

  Future<bool> _coreProcessIsRunning(int pid) async {
    try {
      final name = await File('/proc/$pid/comm').readAsString();
      return name.trim() == _coreBin;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _stopCoreProcessesByName() async {
    var processIds = await _coreProcessIds();
    if (processIds == null) {
      return false;
    }
    if (processIds.isEmpty) {
      await _processStore.clear();
      return true;
    }

    for (final pid in processIds) {
      Process.killPid(pid, ProcessSignal.sigterm);
    }
    if (!await _waitForCoreProcessesExit(Duration(seconds: 3))) {
      processIds = await _coreProcessIds();
      if (processIds == null) {
        return false;
      }
      for (final pid in processIds) {
        Process.killPid(pid, ProcessSignal.sigkill);
      }
      if (!await _waitForCoreProcessesExit(Duration(seconds: 2))) {
        return false;
      }
    }

    await _processStore.clear();
    return true;
  }

  Future<List<int>?> _coreProcessIds() async {
    final effectiveUserId = await (_effectiveUserIdFuture ??=
        _readEffectiveUserId());
    if (effectiveUserId == null) {
      return null;
    }
    try {
      final result = await _processManager.run(<String>[
        'pgrep',
        '-x',
        '-u',
        effectiveUserId,
        _coreBin,
      ]);
      if (result.exitCode == 1) {
        return <int>[];
      }
      if (result.exitCode != 0) {
        ygLogger(
          'find core processes failed. exitCode=${result.exitCode} '
          'stderr=${result.stderr}',
        );
        return null;
      }
      return result.stdout
          .toString()
          .split('\n')
          .map((value) => int.tryParse(value.trim()))
          .whereType<int>()
          .toList(growable: false);
    } catch (error) {
      ygLogger('find core processes failed: $error');
      return null;
    }
  }

  Future<String?> _readEffectiveUserId() async {
    try {
      final result = await _processManager.run(<String>['id', '-u']);
      final value = result.stdout.toString().trim();
      if (result.exitCode == 0 && int.tryParse(value) != null) {
        return value;
      }
      ygLogger(
        'read effective user id failed. exitCode=${result.exitCode} '
        'stderr=${result.stderr}',
      );
    } catch (error) {
      ygLogger('read effective user id failed: $error');
    }
    return null;
  }

  Future<bool> _waitForCoreProcessesExit(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final processIds = await _coreProcessIds();
      if (processIds == null) {
        return false;
      }
      if (processIds.isEmpty) {
        return true;
      }
      if (DateTime.now().isAfter(deadline)) {
        return false;
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
