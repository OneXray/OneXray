import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:isolate_manager/isolate_manager.dart';
import 'package:onexray/core/ffi/generated_bindings.dart';
import 'package:onexray/core/ffi/model_reader.dart';
import 'package:onexray/core/ffi/model_writer.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
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
    final coreConfig = RunXrayConfigReader.readFromStartVpnRequest(request);
    final configPath = await coreConfig.writeToFile();

    var res = await startCore(configPath);
    if (!res) {
      await stopVpn();
      return _commandFailed(appLocalizationsNoContext().vpnCoreStartFailed);
    }
    await updateVpnStatus(VpnStatus.connected);
    return _commandSuccess();
  }

  Future<bool> startCore(String configPath) async {
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

  Future<String> initDns(String base64Text) async {
    return _sharedIsolate.compute(_cgoInitDns, base64Text);
  }

  Future<String> resetDns() async {
    return _sharedIsolate.compute(_cgoResetDns, 0);
  }

  Future<String> getFreePorts(int num) async {
    return _sharedIsolate.compute(_cgoGetFreePorts, num);
  }

  Future<String> convertShareLinksToXrayJson(String base64Text) async {
    return _sharedIsolate.compute(_cgoConvertShareLinksToXrayJson, base64Text);
  }

  Future<String> convertXrayJsonToShareLinks(String base64Text) async {
    return _sharedIsolate.compute(_cgoConvertXrayJsonToShareLinks, base64Text);
  }

  Future<String> countGeoData(String base64Text) async {
    return _sharedIsolate.compute(_cgoCountGeoData, base64Text);
  }

  Future<String> readGeoFiles(String base64Text) async {
    return _sharedIsolate.compute(_cgoReadGeoFiles, base64Text);
  }

  Future<String> ping(String base64Text) async {
    return _sharedIsolate.compute(_cgoPing, base64Text);
  }

  Future<String> testXray(String base64Text) async {
    return _sharedIsolate.compute(_cgoTestXray, base64Text);
  }

  Future<String> runXray(String base64Text) async {
    return _sharedIsolate.compute(_cgoRunXray, base64Text);
  }

  Future<String> stopXray() async {
    return _sharedIsolate.compute(_cgoStopXray, 0);
  }

  Future<String> xrayVersion() async {
    return _sharedIsolate.compute(_cgoXrayVersion, 0);
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
String _cgoInitDns(String base64Text) {
  final req = _convertStringToPointer(base64Text);
  final resPointer = _CoreLib()._lib.CGoInitDns(req);
  calloc.free(req);
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoResetDns(int _) {
  final resPointer = _CoreLib()._lib.CGoResetDns();
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoGetFreePorts(int num) {
  final resPointer = _CoreLib()._lib.CGoGetFreePorts(num);
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoConvertShareLinksToXrayJson(String base64Text) {
  final req = _convertStringToPointer(base64Text);
  final resPointer = _CoreLib()._lib.CGoConvertShareLinksToXrayJson(req);
  calloc.free(req);
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoConvertXrayJsonToShareLinks(String base64Text) {
  final req = _convertStringToPointer(base64Text);
  final resPointer = _CoreLib()._lib.CGOConvertXrayJsonToShareLinks(req);
  calloc.free(req);
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoCountGeoData(String base64Text) {
  final req = _convertStringToPointer(base64Text);
  final resPointer = _CoreLib()._lib.CGoCountGeoData(req);
  calloc.free(req);
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoReadGeoFiles(String base64Text) {
  final req = _convertStringToPointer(base64Text);
  final resPointer = _CoreLib()._lib.CGoReadGeoFiles(req);
  calloc.free(req);
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoPing(String base64Text) {
  final req = _convertStringToPointer(base64Text);
  final resPointer = _CoreLib()._lib.CGoPing(req);
  calloc.free(req);
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoTestXray(String base64Text) {
  final req = _convertStringToPointer(base64Text);
  final resPointer = _CoreLib()._lib.CGoTestXray(req);
  calloc.free(req);
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoRunXray(String base64Text) {
  final req = _convertStringToPointer(base64Text);
  final resPointer = _CoreLib()._lib.CGoRunXray(req);
  calloc.free(req);
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoStopXray(int _) {
  final resPointer = _CoreLib()._lib.CGoStopXray();
  final res = _convertPointerToString(resPointer);
  return res;
}

@pragma('vm:entry-point')
@isolateManagerSharedWorker
String _cgoXrayVersion(int _) {
  final resPointer = _CoreLib()._lib.CGoXrayVersion();
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
