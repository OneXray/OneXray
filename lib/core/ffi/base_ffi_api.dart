import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:onexray/core/ffi/generated_bindings.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/localizations/service.dart';

abstract class BaseFfiApi {
  Future<String> getTunFilesDir() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  var _vpnStatus = VpnStatus.disconnected;

  Future<NativeVpnCommandResult> readVpnStatus() async {
    await AppFlutterApi().vpnStatusChanged(_vpnStatus);
    return _commandSuccess();
  }

  Future<void> updateVpnStatus(VpnStatus status) async {
    _vpnStatus = status;
    await AppFlutterApi().vpnStatusChanged(_vpnStatus);
  }

  Future<NativeVpnCommandResult> startVpn() async {
    await updateVpnStatus(VpnStatus.connecting);

    final request = await StartVpnRequestReader.readFromStartFile();
    final coreRequest = _readRunXrayRequest(request);

    var res = await startCore(coreRequest);
    if (!res) {
      await stopVpn();
      return _commandFailed(appLocalizationsNoContext().vpnCoreStartFailed);
    }
    await updateVpnStatus(VpnStatus.connected);
    return _commandSuccess();
  }

  LibXrayRunConfig _readRunXrayRequest(StartVpnRequest request) {
    if (!EmptyTool.checkString(request.coreInvokeText)) {
      return LibXrayRunConfig(null, RunXrayRequest(null));
    }
    return LibXrayRunConfig.fromInvokeText(request.coreInvokeText!);
  }

  Future<bool> startCore(LibXrayRunConfig request) async {
    return true;
  }

  void stopCore() {}

  Future<NativeVpnCommandResult> stopVpn() async {
    await updateVpnStatus(VpnStatus.disconnecting);
    stopCore();
    await Future.delayed(Duration(seconds: 1));
    await updateVpnStatus(VpnStatus.disconnected);
    return _commandSuccess();
  }

  PlatformPermissionResult _permissionNotRequired() {
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.none,
      state: PlatformPermissionState.notRequired,
    );
  }

  NativeVpnCommandResult _commandSuccess() {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.success,
      permission: _permissionNotRequired(),
    );
  }

  NativeVpnCommandResult _commandFailed(String message) {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.failed,
      permission: _permissionNotRequired(),
      message: message,
    );
  }

  final _sharedIsolate = IsolateManager.createShared(concurrent: 1);
  void stopSharedIsolate() {
    _sharedIsolate.stop();
  }

  Future<String> invoke(String requestJson) async {
    return _sharedIsolate.compute(_cgoInvoke, requestJson);
  }
}

class _CoreLib {
  late final NativeLibrary _lib;

  static final _CoreLib _singleton = _CoreLib._internal();

  factory _CoreLib() => _singleton;

  _CoreLib._internal() {
    var libName = "";
    if (AppPlatform.isLinux) {
      libName = "libXray.so";
    } else if (AppPlatform.isWindows) {
      libName = "libXray.dll";
    }
    final lib = DynamicLibrary.open(libName);
    _lib = NativeLibrary(lib);
  }
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoInvoke(String requestJson) {
  final req = _convertStringToPointer(requestJson);
  final resPointer = _CoreLib()._lib.CGoInvoke(req);
  calloc.free(req);
  final res = _convertPointerToString(resPointer);
  return res;
}

Pointer<Char> _convertStringToPointer(String text) {
  final pointer = text.toNativeUtf8().cast<Char>();
  return pointer;
}

String _convertPointerToString(Pointer<Char> pointer) {
  final text = pointer.cast<Utf8>().toDartString();
  calloc.free(pointer);
  return text;
}
