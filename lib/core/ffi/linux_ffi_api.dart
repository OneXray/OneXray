import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as p;
import 'package:process/process.dart';

class LinuxFfiApi extends BaseFfiApi {
  static final LinuxFfiApi _singleton = LinuxFfiApi._internal();

  factory LinuxFfiApi() => _singleton;

  LinuxFfiApi._internal() {
    unawaited(_killAll());
  }

  //===================================
  static const _coreBin = "OneXrayCore";
  static const _stopProxyCoreFailed = "stop proxy core failed";
  final _processManager = LocalProcessManager();

  @override
  Future<NativeVpnCommandResult> startVpn() async {
    await _killAll();
    return super.startVpn();
  }

  Future<bool> _killAll() async {
    var success = true;
    final names = <String>[_coreBin];
    for (final name in names) {
      success = await _killProcesses(name) && success;
    }
    return success;
  }

  Future<bool> _killProcesses(String name) async {
    final command = <String>["pgrep", name];
    final p = await _processManager.run(command);
    final String stdout = p.stdout;
    final processes = stdout.trim().split("\n");
    var success = true;
    for (final process in processes) {
      final pid = int.tryParse(process);
      if (pid != null) {
        success = _processManager.killPid(pid) && success;
      }
    }
    return success;
  }

  Process? _coreProcess;

  @override
  Future<bool> startCore(LibXrayRunConfig request) async {
    try {
      final xrayConfigPath = request.request.configPath;
      if (xrayConfigPath == null || xrayConfigPath.isEmpty) {
        ygLogger("start core failed: configPath is empty");
        return false;
      }

      final command = <String>[corePath, "run", "-config", xrayConfigPath];
      ygLogger("Running command: ${command.join(" ")}");
      final process = await _processManager.start(command);
      _bindProcess(process);
      _coreProcess = process;
      _trackProcess(process);
    } catch (e) {
      ygLogger("start core failed: $e");
      return false;
    }

    await Future.delayed(Duration(seconds: 1));

    return proxyCoreRunning();
  }

  Future<bool> startProxyCore(String configPath) async {
    await _killAll();
    return startCore(LibXrayRunConfig(RunXrayRequest(configPath)));
  }

  @override
  void stopCore() {
    final process = _coreProcess;
    if (process != null) {
      process.kill();
      _coreProcess = null;
    }
  }

  Future<String> stopProxyCore() async {
    final stopped = await _stopProxyCore();
    return stopped ? "" : _stopProxyCoreFailed;
  }

  bool proxyCoreRunning() {
    return _coreProcess != null;
  }

  Future<bool> _stopProxyCore() async {
    final process = _coreProcess;
    if (process == null) {
      return _killAll();
    }
    if (!process.kill()) {
      return false;
    }
    try {
      await process.exitCode.timeout(Duration(seconds: 3));
      _coreProcess = null;
      return true;
    } on TimeoutException {
      return false;
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
      }
    });
  }
}
