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
    _killAll();
  }

  //===================================
  static const _coreBin = "OneXrayCore";
  final _processManager = LocalProcessManager();

  @override
  Future<NativeVpnCommandResult> startVpn() async {
    await _killAll();
    return super.startVpn();
  }

  Future<void> _killAll() async {
    final names = <String>[_coreBin];
    for (final name in names) {
      await _killProcesses(name);
    }
  }

  Future<void> _killProcesses(String name) async {
    final command = <String>["pgrep", name];
    final p = await _processManager.run(command);
    final String stdout = p.stdout;
    final processes = stdout.trim().split("\n");
    for (final process in processes) {
      final pid = int.tryParse(process);
      if (pid != null) {
        _processManager.killPid(pid);
      }
    }
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

  String stopProxyCore() {
    stopCore();
    return "";
  }

  bool proxyCoreRunning() {
    return _coreProcess != null;
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
