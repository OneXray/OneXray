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
  static const _waitTimeout = 258;

  HANDLE? _coreProcess;
  HANDLE? _proxyProcess;

  @override
  Future<bool> startCore(LibXrayRunConfig request) async {
    try {
      final xrayConfigPath = request.request.configPath;
      if (xrayConfigPath == null || xrayConfigPath.isEmpty) {
        ygLogger("start core failed: configPath is empty");
        return false;
      }

      final parameters = <String>[
        "run",
        "-config",
        _quoteArg(xrayConfigPath),
      ].join(" ");
      final result = _runCommand(Tuple3("runas", corePath, parameters));
      if (!result.item1) {
        final errorCode = GetLastError();
        ygLogger("Start core failed. errorCode=$errorCode");
        return false;
      }
      _coreProcess = result.item2;
      ygLogger("Core process started with handle: $_coreProcess");
    } catch (e) {
      ygLogger("start core failed: $e");
      return false;
    }

    await Future.delayed(Duration(seconds: 1));
    return true;
  }

  Future<bool> startProxyCore(String configPath) async {
    try {
      if (configPath.isEmpty) {
        ygLogger("start proxy core failed: configPath is empty");
        return false;
      }
      stopProxyCore();

      final parameters = <String>[
        "run",
        "-config",
        _quoteArg(configPath),
      ].join(" ");
      final result = _runCommand(Tuple3("open", corePath, parameters));
      if (!result.item1) {
        final errorCode = GetLastError();
        ygLogger("Start proxy core failed. errorCode=$errorCode");
        return false;
      }
      _proxyProcess = result.item2;
      ygLogger("Proxy core process started with handle: $_proxyProcess");
    } catch (e) {
      ygLogger("start proxy core failed: $e");
      return false;
    }

    await Future.delayed(Duration(seconds: 1));
    return proxyCoreRunning();
  }

  @override
  void stopCore() {
    if (_coreProcess == null) {
      return;
    }

    final processHandle = _coreProcess!;
    ygLogger("Stopping core process with handle: $processHandle");

    final terminateResult = TerminateProcess(processHandle, 0);
    if (terminateResult.value) {
      final waitResult = WaitForSingleObject(processHandle, 3000);
      ygLogger("Core process termination wait result: $waitResult");
    } else {
      final errorCode = GetLastError();
      ygLogger("TerminateProcess failed. errorCode=$errorCode");
    }

    final closeResult = CloseHandle(processHandle);
    if (!closeResult.value) {
      final errorCode = GetLastError();
      ygLogger("CloseHandle failed. errorCode=$errorCode");
    }
    _coreProcess = null;
  }

  String stopProxyCore() {
    final processHandle = _proxyProcess;
    if (processHandle == null) {
      return "";
    }

    ygLogger("Stopping proxy core process with handle: $processHandle");
    final terminateResult = TerminateProcess(processHandle, 0);
    if (terminateResult.value) {
      final waitResult = WaitForSingleObject(processHandle, 3000);
      ygLogger("Proxy core termination wait result: $waitResult");
    } else {
      final errorCode = GetLastError();
      ygLogger("Terminate proxy core failed. errorCode=$errorCode");
    }

    final closeResult = CloseHandle(processHandle);
    if (!closeResult.value) {
      final errorCode = GetLastError();
      ygLogger("Close proxy core handle failed. errorCode=$errorCode");
    }
    _proxyProcess = null;
    return "";
  }

  bool proxyCoreRunning() {
    final processHandle = _proxyProcess;
    if (processHandle == null) {
      return false;
    }
    final waitResult = WaitForSingleObject(processHandle, 0);
    if (waitResult.value == _waitTimeout) {
      return true;
    }
    CloseHandle(processHandle);
    _proxyProcess = null;
    return false;
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

  String _quoteArg(String value) {
    return '"${value.replaceAll('"', r'\"')}"';
  }
}
