import 'dart:async';
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

class _ShellLaunchResult {
  final bool started;
  final HANDLE processHandle;

  const _ShellLaunchResult(this.started, this.processHandle);
}

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

  final _processStore = DesktopCoreProcessStore();
  HANDLE? _processHandle;
  int? _processId;
  Timer? _processMonitor;
  bool _stopping = false;

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
    );
  }

  Future<bool> startProxyCore(LibXrayRunConfig request) async {
    final configPath = request.request.configPath;
    if (configPath == null || configPath.isEmpty) {
      ygLogger("start proxy core failed: config path is empty");
      return false;
    }

    return _startCoreProcess(
      label: "proxy core",
      verb: "open",
      configPath: configPath,
    );
  }

  Future<bool> cleanupStaleCore() async {
    if (_processHandle != null) {
      return true;
    }
    return _stopRecordedCore();
  }

  @override
  Future<bool> stopCore() => _stopProcess(label: "core");

  Future<String> stopProxyCore() async {
    final stopped = await _stopProcess(label: "proxy core");
    return stopped ? "" : _stopProxyCoreFailed;
  }

  Future<bool> proxyCoreRunning() async => await queryCoreRunning() ?? false;

  String get corePath {
    final bundleDir = p.dirname(Platform.resolvedExecutable);
    final corePath = p.join(bundleDir, "bin", _coreExe);
    return corePath;
  }

  _ShellLaunchResult _runCommand({
    required String verb,
    required String file,
    required String parameters,
  }) {
    ygLogger("Running command: $verb $file $parameters");
    final lpVerb = verb.toPwstr();
    final lpFile = file.toPwstr();
    final lpParameters = parameters.toPwstr();

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
      return _ShellLaunchResult(result.value, process);
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
  }) async {
    if (!await _stopProcess(label: label)) {
      return false;
    }

    try {
      final result = _runCommand(
        verb: verb,
        file: corePath,
        parameters: _buildRunParameters(configPath),
      );
      if (!result.started || !result.processHandle.isValid) {
        final errorCode = GetLastError();
        ygLogger("Start $label failed. errorCode=$errorCode");
        return false;
      }
      _processHandle = result.processHandle;
      final pid = GetProcessId(result.processHandle).value;
      if (pid == 0) {
        ygLogger("Start $label failed: process id is unavailable");
        await _stopProcess(label: label);
        return false;
      }
      _processId = pid;
      await _processStore.write(
        DesktopCoreProcessRecord(pid: pid, executablePath: corePath),
      );
      _startProcessMonitor(label);
      ygLogger("$label process started with pid: $pid");
    } catch (e) {
      ygLogger("start $label failed: $e");
      await _stopProcess(label: label);
      return false;
    }

    await Future.delayed(Duration(seconds: 1));
    return await queryCoreRunning() ?? false;
  }

  String _buildRunParameters(String configPath) {
    return <String>["run", "-config", _quoteArg(configPath)].join(" ");
  }

  @override
  Future<bool?> queryCoreRunning() async {
    if (_processHandle == null) {
      return false;
    }
    return _processRunning(label: "core");
  }

  Future<bool> _stopRecordedCore() async {
    final record = await _processStore.read();
    if (record == null) {
      return true;
    }

    var opened = OpenProcess(
      PROCESS_QUERY_LIMITED_INFORMATION |
          PROCESS_SYNCHRONIZE |
          PROCESS_TERMINATE,
      false,
      record.pid,
    );
    if (!opened.value.isValid) {
      opened = OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_SYNCHRONIZE,
        false,
        record.pid,
      );
    }
    final handle = opened.value;
    if (!handle.isValid) {
      final errorCode = GetLastError();
      ygLogger(
        "Open stale core process failed. pid=${record.pid} "
        "errorCode=$errorCode",
      );
      if (errorCode == ERROR_INVALID_PARAMETER) {
        await _processStore.clear(pid: record.pid);
        return true;
      }
      return false;
    }

    try {
      final imagePath = _queryProcessImagePath(handle);
      if (imagePath == null) {
        return false;
      }
      if (!_samePath(imagePath, record.executablePath)) {
        await _processStore.clear(pid: record.pid);
        return true;
      }

      final currentWaitResult = WaitForSingleObject(handle, 0);
      if (currentWaitResult.value == _waitObject0) {
        await _processStore.clear(pid: record.pid);
        return true;
      }
      if (currentWaitResult.value != _waitTimeout) {
        _logWaitError("stale core", currentWaitResult.value);
        return false;
      }

      final terminateResult = TerminateProcess(handle, 0);
      if (!terminateResult.value) {
        final errorCode = GetLastError();
        ygLogger(
          "Terminate stale core process failed. errorCode=$errorCode; "
          "requesting elevated PID termination",
        );
        if (!await _terminatePidElevated(record.pid)) {
          return false;
        }
      }

      final waitResult = WaitForSingleObject(handle, 3000);
      ygLogger("stale core process termination wait result: $waitResult");
      if (waitResult.value != _waitObject0) {
        return false;
      }
      await _processStore.clear(pid: record.pid);
      return true;
    } finally {
      _closeProcessHandle("stale core", handle);
    }
  }

  Future<bool> _stopProcess({required String label}) async {
    if (_processHandle == null) {
      return _stopRecordedCore();
    }
    final processHandle = _processHandle!;
    final processId = _processId;
    _stopping = true;
    _processMonitor?.cancel();
    _processMonitor = null;

    ygLogger("Stopping $label process with handle: $processHandle");
    final currentWaitResult = WaitForSingleObject(processHandle, 0);
    if (currentWaitResult.value == _waitObject0) {
      ygLogger(
        "$label process already stopped. wait result: $currentWaitResult",
      );
      await _releaseProcess(label, processHandle, processId);
      _stopping = false;
      return true;
    }
    if (currentWaitResult.value != _waitTimeout) {
      _logWaitError(label, currentWaitResult.value);
      _startProcessMonitor(label);
      _stopping = false;
      return false;
    }

    final terminateResult = TerminateProcess(processHandle, 0);
    if (!terminateResult.value && processId != null) {
      final errorCode = GetLastError();
      ygLogger(
        "Terminate $label process failed. errorCode=$errorCode; "
        "requesting elevated PID termination",
      );
      if (!await _terminatePidElevated(processId)) {
        _startProcessMonitor(label);
        _stopping = false;
        return false;
      }
    }

    final waitResult = WaitForSingleObject(processHandle, 3000);
    ygLogger("$label process termination wait result: $waitResult");
    if (waitResult.value != _waitObject0) {
      _startProcessMonitor(label);
      _stopping = false;
      return false;
    }

    await _releaseProcess(label, processHandle, processId);
    _stopping = false;
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

    final processId = _processId;
    _closeProcessHandle(label, processHandle);
    _processHandle = null;
    _processId = null;
    unawaited(_processStore.clear(pid: processId));
    return false;
  }

  void _startProcessMonitor(String label) {
    _processMonitor?.cancel();
    _processMonitor = Timer.periodic(Duration(seconds: 1), (_) async {
      if (_stopping || _processRunning(label: label)) {
        return;
      }
      _processMonitor?.cancel();
      _processMonitor = null;
      await updateVpnStatus(VpnStatus.disconnected);
    });
  }

  Future<void> _releaseProcess(
    String label,
    HANDLE processHandle,
    int? processId,
  ) async {
    _closeProcessHandle(label, processHandle);
    _processHandle = null;
    _processId = null;
    await _processStore.clear(pid: processId);
  }

  Future<bool> _terminatePidElevated(int pid) async {
    final result = _runCommand(
      verb: "runas",
      file: "taskkill.exe",
      parameters: "/PID $pid /T /F",
    );
    if (!result.started || !result.processHandle.isValid) {
      return false;
    }
    final waitResult = WaitForSingleObject(result.processHandle, 5000);
    _closeProcessHandle("taskkill", result.processHandle);
    return waitResult.value == _waitObject0;
  }

  String? _queryProcessImagePath(HANDLE handle) {
    const capacity = 32768;
    final buffer = wsalloc(capacity);
    final length = calloc<Uint32>()..value = capacity;
    try {
      final result = QueryFullProcessImageName(
        handle,
        PROCESS_NAME_WIN32,
        buffer,
        length,
      );
      if (!result.value) {
        return null;
      }
      return buffer.toDartString(length: length.value);
    } finally {
      free(buffer);
      free(length);
    }
  }

  bool _samePath(String first, String second) {
    return p.normalize(first).toLowerCase() ==
        p.normalize(second).toLowerCase();
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
