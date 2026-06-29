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

  var _coreProcess = 0;

  @override
  Future<bool> startCore(RunXrayRequest request) async {
    try {
      final xrayConfigPath = request.configPath;
      final datDir = request.datDir;
      if (xrayConfigPath == null || xrayConfigPath.isEmpty) {
        ygLogger("start core failed: configPath is empty");
        return false;
      }
      if (datDir == null || datDir.isEmpty) {
        ygLogger("start core failed: datDir is empty");
        return false;
      }

      final command = <String>[
        corePath,
        "run",
        "-config",
        xrayConfigPath,
        "--env",
        "XRAY_LOCATION_ASSET=$datDir",
      ];
      ygLogger("Running command: ${command.join(" ")}");
      final process = await _processManager.start(command);
      _bindProcess(process);
      _coreProcess = process.pid;
    } catch (e) {
      ygLogger("start core failed: $e");
      return false;
    }

    await Future.delayed(Duration(seconds: 1));

    return true;
  }

  @override
  void stopCore() {
    if (_coreProcess != 0) {
      _processManager.killPid(_coreProcess);
      _coreProcess = 0;
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

  void _bindProcess(Process p) {
    if (!kReleaseMode) {
      p.stdout.listen((data) {
        final text = utf8.decode(data);
        ygLogger(text);
      });
    }
  }
}
