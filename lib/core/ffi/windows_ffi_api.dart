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

  HANDLE? _coreProcess;

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

      final envArg = "XRAY_LOCATION_ASSET=$datDir";
      final parameters = <String>[
        "run",
        "-config",
        _quoteArg(xrayConfigPath),
        "--env",
        _quoteArg(envArg),
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
