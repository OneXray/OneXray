import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';
import 'package:win32/win32.dart';

class WindowsFfiApi extends BaseFfiApi {
  static final WindowsFfiApi _singleton = WindowsFfiApi._internal();

  factory WindowsFfiApi() => _singleton;

  WindowsFfiApi._internal();

  //===================================

  static const _coreExe = "OneXrayCore.exe";
  static const _waitObject0 = 0;
  static const _waitTimeout = 258;
  static const _waitFailed = 0xFFFFFFFF;
  static const _stopProxyCoreFailed = "stop proxy core failed";

  HANDLE? _processHandle;

  @override
  Future<bool> startCore(LibXrayRunConfig request) async {
    final configPath = request.request.configPath;
    if (configPath == null || configPath.isEmpty) {
      ygLogger("start core failed: config path is empty");
      return false;
    }

    return _startCoreProcess(
      label: "core",
      verb: "runas",
      configPath: configPath,
      verifyRunning: false,
    );
  }

  Future<bool> startProxyCore(LibXrayRunConfig request) async {
    final configPath = request.request.configPath;
    if (configPath == null || configPath.isEmpty) {
      ygLogger("start proxy core failed: config path is empty");
      return false;
    }

    if (!await _killExistingCoreProcesses()) {
      return false;
    }
    if (_existingCoreProcessRunning()) {
      ygLogger("start proxy core failed: existing $_coreExe is still running");
      return false;
    }
    return _startCoreProcess(
      label: "proxy core",
      verb: "open",
      configPath: configPath,
      verifyRunning: true,
      isRunning: () => _processRunning(label: "proxy core"),
    );
  }

  @override
  void stopCore() {
    _stopProcess(label: "core");
  }

  Future<String> stopProxyCore() async {
    final stopped = _processHandle == null
        ? _killExistingCoreProcessesSync()
        : _stopProcess(label: "proxy core");
    return stopped ? "" : _stopProxyCoreFailed;
  }

  bool proxyCoreRunning() {
    if (_processRunning(label: "proxy core")) {
      return true;
    }
    return _existingCoreProcessRunning();
  }

  String get corePath {
    final bundleDir = p.dirname(Platform.resolvedExecutable);
    final corePath = p.join(bundleDir, "bin", _coreExe);
    return corePath;
  }

  Tuple2<bool, HANDLE> _runCommand(Tuple3<String, String, String> command) {
    ygLogger(
      "Running command: ${command.item1} ${command.item2} ${command.item3}",
    );
    final lpVerb = command.item1.toPwstr();
    final lpFile = command.item2.toPwstr();
    final lpParameters = command.item3.toPwstr();

    final Pointer<SHELLEXECUTEINFO> info = calloc<SHELLEXECUTEINFO>();
    try {
      info.ref.cbSize = sizeOf<SHELLEXECUTEINFO>();
      //SEE_MASK_NOCLOSEPROCESS
      info.ref.fMask = 0x00000040;
      info.ref.lpVerb = lpVerb;
      info.ref.lpFile = lpFile;
      info.ref.lpParameters = lpParameters;
      info.ref.nShow = SW_HIDE;
      final result = ShellExecuteEx(info);
      final process = info.ref.hProcess;
      return Tuple2(result.value, process);
    } finally {
      free(info);
      free(lpVerb);
      free(lpFile);
      free(lpParameters);
    }
  }

  Future<bool> _startCoreProcess({
    required String label,
    required String verb,
    required String configPath,
    required bool verifyRunning,
    bool Function()? isRunning,
  }) async {
    if (!_stopProcess(label: label)) {
      return false;
    }

    try {
      final result = _runCommand(
        Tuple3(verb, corePath, _buildRunParameters(configPath)),
      );
      if (!result.item1) {
        final errorCode = GetLastError();
        ygLogger("Start $label failed. errorCode=$errorCode");
        return false;
      }
      _processHandle = result.item2;
      ygLogger("$label process started with handle: ${result.item2}");
    } catch (e) {
      ygLogger("start $label failed: $e");
      return false;
    }

    await Future.delayed(Duration(seconds: 1));
    return verifyRunning ? isRunning?.call() ?? false : true;
  }

  String _buildRunParameters(String configPath) {
    return <String>["run", "-config", _quoteArg(configPath)].join(" ");
  }

  Future<bool> _killExistingCoreProcesses() async {
    try {
      final result = await Process.run("taskkill", ["/F", "/IM", _coreExe]);
      return _handleKillExistingCoreProcessesResult(result);
    } catch (e) {
      ygLogger("kill existing core processes failed: $e");
      return !_existingCoreProcessRunning();
    }
  }

  bool _killExistingCoreProcessesSync() {
    try {
      final result = Process.runSync("taskkill", ["/F", "/IM", _coreExe]);
      return _handleKillExistingCoreProcessesResult(result);
    } catch (e) {
      ygLogger("kill existing core processes failed: $e");
      return !_existingCoreProcessRunning();
    }
  }

  bool _handleKillExistingCoreProcessesResult(ProcessResult result) {
    if (result.exitCode == 0) {
      ygLogger("Killed existing $_coreExe processes");
      return true;
    }
    if (!_existingCoreProcessRunning()) {
      return true;
    }
    ygLogger(
      "kill existing core processes failed. "
      "exitCode=${result.exitCode} stderr=${result.stderr}",
    );
    return false;
  }

  bool _existingCoreProcessRunning() {
    try {
      final result = Process.runSync("tasklist", [
        "/FI",
        "IMAGENAME eq $_coreExe",
        "/NH",
      ]);
      if (result.exitCode != 0) {
        return false;
      }
      final output = result.stdout.toString().toLowerCase();
      final coreExe = _coreExe.toLowerCase();
      return output
          .split("\n")
          .map((line) => line.trim())
          .any((line) => line.startsWith(coreExe));
    } catch (e) {
      ygLogger("check existing core process failed: $e");
      return false;
    }
  }

  bool _stopProcess({required String label}) {
    final processHandle = _processHandle;
    if (processHandle == null) {
      return true;
    }

    ygLogger("Stopping $label process with handle: $processHandle");
    final currentWaitResult = WaitForSingleObject(processHandle, 0);
    if (currentWaitResult.value == _waitObject0) {
      ygLogger(
        "$label process already stopped. wait result: $currentWaitResult",
      );
      _closeProcessHandle(label, processHandle);
      _processHandle = null;
      return true;
    }
    if (currentWaitResult.value != _waitTimeout) {
      _logWaitError(label, currentWaitResult.value);
      return false;
    }

    final terminateResult = TerminateProcess(processHandle, 0);
    if (terminateResult.value) {
      final waitResult = WaitForSingleObject(processHandle, 3000);
      ygLogger("$label process termination wait result: $waitResult");
      if (waitResult.value != _waitObject0) {
        return false;
      }
    } else {
      final errorCode = GetLastError();
      ygLogger("Terminate $label process failed. errorCode=$errorCode");
      return false;
    }

    _closeProcessHandle(label, processHandle);
    _processHandle = null;
    return true;
  }

  bool _processRunning({required String label}) {
    final processHandle = _processHandle;
    if (processHandle == null) {
      return false;
    }

    final waitResult = WaitForSingleObject(processHandle, 0);
    if (waitResult.value == _waitTimeout) {
      return true;
    }
    if (waitResult.value != _waitObject0) {
      _logWaitError(label, waitResult.value);
      return true;
    }

    _closeProcessHandle(label, processHandle);
    _processHandle = null;
    return false;
  }

  void _logWaitError(String label, int waitResult) {
    final errorCode = waitResult == _waitFailed ? GetLastError() : null;
    ygLogger(
      "Wait $label process failed. waitResult=$waitResult errorCode=$errorCode",
    );
  }

  void _closeProcessHandle(String label, HANDLE processHandle) {
    final closeResult = CloseHandle(processHandle);
    if (!closeResult.value) {
      final errorCode = GetLastError();
      ygLogger("Close $label process handle failed. errorCode=$errorCode");
    }
  }

  String _quoteArg(String value) {
    return '"${value.replaceAll('"', r'\"')}"';
  }
}
