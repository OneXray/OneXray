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
    return _startCoreProcess(label: "core", verb: "runas", request: request);
  }

  Future<bool> startProxyCore(LibXrayRunConfig request) async {
    return _startCoreProcess(
      label: "proxy core",
      verb: "open",
      request: request,
    );
  }

  Future<bool> cleanupStaleCore() async {
    if (_processHandle != null) {
      return true;
    }
    return _stopCoreProcessesByName();
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
    required LibXrayRunConfig request,
  }) async {
    if (!await _stopProcess(label: label)) {
      return false;
    }

    try {
      final configPath = await materializeRunXrayConfig(request);
      if (configPath == null) {
        ygLogger("start $label failed: xrayJson is empty");
        return false;
      }
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
      await _processStore.write(DesktopCoreProcessRecord(pid: pid));
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
      }
    } catch (error) {
      ygLogger('stop core processes failed: $error');
    }

    if (!await _waitForCoreProcessesExit(
      sessionId,
      Duration(milliseconds: 500),
    )) {
      final result = _runCommand(
        verb: 'runas',
        file: 'taskkill.exe',
        parameters: '/F /T /FI "SESSION eq $sessionId" /IM $_coreExe',
      );
      if (!result.started || !result.processHandle.isValid) {
        return false;
      }
      final waitResult = WaitForSingleObject(result.processHandle, 5000);
      _closeProcessHandle('taskkill', result.processHandle);
      if (waitResult.value != _waitObject0 ||
          !await _waitForCoreProcessesExit(sessionId, Duration(seconds: 3))) {
        return false;
      }
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
      await Future.delayed(Duration(milliseconds: 100));
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

  Future<bool> _stopProcess({required String label}) async {
    if (_processHandle == null) {
      return _stopCoreProcessesByName();
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
