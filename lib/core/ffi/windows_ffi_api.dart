import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
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

  var _coreProcess = 0;

  @override
  Future<bool> startCore(String configPath) async {
    final result = _runCommand(
      Tuple3("runas", corePath, "-configPath $configPath"),
    );
    _coreProcess = result.item2;
    ygLogger("Core process started with PID: $_coreProcess");

    await Future.delayed(Duration(seconds: 1));

    return true;
  }

  @override
  void stopCore() {
    if (_coreProcess == 0) {
      return;
    }

    final processHandle = _coreProcess;
    ygLogger("Stopping core process with handle: $processHandle");

    final terminateResult = TerminateProcess(processHandle, 0);
    if (terminateResult == 0) {
      final errorCode = GetLastError();
      ygLogger("TerminateProcess failed. errorCode=$errorCode");
    } else {
      final waitResult = WaitForSingleObject(processHandle, 3000);
      ygLogger("Core process termination wait result: $waitResult");
    }

    final closeResult = CloseHandle(processHandle);
    if (closeResult == 0) {
      final errorCode = GetLastError();
      ygLogger("CloseHandle failed. errorCode=$errorCode");
    }

    _coreProcess = 0;
  }

  String get corePath {
    final bundleDir = p.dirname(Platform.resolvedExecutable);
    final corePath = p.join(bundleDir, "bin", _coreExe);
    return corePath;
  }

  Tuple2<bool, int> _runCommand(Tuple3<String, String, String> command) {
    final lpVerb = command.item1.toNativeUtf16();
    final lpFile = command.item2.toNativeUtf16();
    final lpParameters = command.item3.toNativeUtf16();

    final Pointer<SHELLEXECUTEINFO> info = calloc<SHELLEXECUTEINFO>();
    info.ref.cbSize = sizeOf<SHELLEXECUTEINFO>();
    //SEE_MASK_NOCLOSEPROCESS
    info.ref.fMask = 0x00000040;
    info.ref.lpVerb = lpVerb;
    info.ref.lpFile = lpFile;
    info.ref.lpParameters = lpParameters;
    info.ref.nShow = SW_HIDE;
    final result = ShellExecuteEx(info);
    final process = info.ref.hProcess;
    free(info);
    free(lpVerb);
    free(lpFile);
    free(lpParameters);
    return Tuple2(result == TRUE, process);
  }
}
