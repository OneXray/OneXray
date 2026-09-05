import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:isolate_manager/isolate_manager.dart';
import 'package:onexray/core/ffi/generated_bindings.dart';
import 'package:onexray/core/model/tun_json.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:path_provider/path_provider.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:path/path.dart' as p;

List<String> desktopCoreRunArguments({
  required String dns,
  required String interfaceName,
  required String configPath,
  String? runtimePath,
}) {
  if (dns.isEmpty ||
      interfaceName.isEmpty ||
      configPath.isEmpty ||
      runtimePath?.isEmpty == true) {
    throw const FormatException(
      'Desktop Core DNS, interface, or config path is missing',
    );
  }
  return <String>[
    'run',
    '-dns',
    '$dns:53',
    '-interface',
    interfaceName,
    '-config',
    configPath,
    if (runtimePath != null) ...['-runtime', runtimePath],
  ];
}

abstract class BaseFfiApi {
  Future<String> getTunFilesDir() async {
    final dir = await getApplicationSupportDirectory();
    return dir.path;
  }

  var _vpnStatus = VpnStatus.disconnected;

  Future<NativeVpnCommandResult> readVpnStatus() async {
    final running = await queryCoreRunning();
    if (running != null &&
        _vpnStatus != VpnStatus.connecting &&
        _vpnStatus != VpnStatus.disconnecting) {
      _vpnStatus = running ? VpnStatus.connected : VpnStatus.disconnected;
    }
    await AppFlutterApi().vpnStatusChanged(_vpnStatus);
    return commandSuccess();
  }

  Future<bool?> queryCoreRunning() async => null;

  Future<void> updateVpnStatus(VpnStatus status) async {
    _vpnStatus = status;
    await AppFlutterApi().vpnStatusChanged(_vpnStatus);
  }

  Future<NativeVpnCommandResult> startVpn() async {
    await updateVpnStatus(VpnStatus.connecting);

    final request = await StartVpnRequestReader.readFromStartFile();
    final coreRequest = readRunXrayRequest(request);

    var res = await startCore(coreRequest, request.tun);
    if (!res) {
      await stopVpn();
      return commandFailed();
    }
    await updateVpnStatus(VpnStatus.connected);
    return commandSuccess();
  }

  @protected
  LibXrayRunConfig readRunXrayRequest(StartVpnRequest request) {
    if (!EmptyTool.checkString(request.coreInvokeText)) {
      return LibXrayRunConfig(
        LibXrayInvokeRequest(
          method: LibXrayMethod.runXray,
          payload: RunXrayRequest(null).toJson(),
        ),
      );
    }
    return LibXrayRunConfig.fromInvokeText(request.coreInvokeText!);
  }

  Future<bool> startCore(LibXrayRunConfig request, TunJson? tun) async {
    return true;
  }

  Future<({String configPath, String? runtimePath})?> materializeRunXrayConfig(
    LibXrayRunConfig request,
  ) async {
    final runPath = p.join(await getTunFilesDir(), 'run');
    final root = Directory(p.join(runPath, 'core-inputs'));
    final type = await FileSystemEntity.type(root.path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await root.delete(recursive: true);
    } else if (type != FileSystemEntityType.notFound) {
      throw const FormatException('Invalid desktop Core input directory');
    }
    await root.create(recursive: true);
    final xrayJson = request.request.xrayJson;
    if (xrayJson == null || xrayJson.isEmpty) {
      return null;
    }

    final runtime = request.request.runtime;
    final directory = await root.createTemp('input-');
    try {
      final config = File(p.join(directory.path, 'xray.json'));
      await config.writeAsString(xrayJson, flush: true);
      String? runtimePath;
      if (runtime != null) {
        runtimePath = p.join(directory.path, 'runtime-config.json');
        await File(runtimePath)
            .writeAsString(jsonEncode(runtime.toJson()), flush: true);
      }
      return (configPath: config.path, runtimePath: runtimePath);
    } catch (_) {
      if (await directory.exists()) await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<bool> stopCore() async => true;

  Future<NativeVpnCommandResult> stopVpn() async {
    await updateVpnStatus(VpnStatus.disconnecting);
    final stopped = await stopCore();
    if (!stopped) {
      await updateVpnStatus(VpnStatus.connected);
      return commandFailed();
    }
    await Future.delayed(Duration(seconds: 1));
    await updateVpnStatus(VpnStatus.disconnected);
    return commandSuccess();
  }

  PlatformPermissionResult _permissionNotRequired() {
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.none,
      state: PlatformPermissionState.notRequired,
    );
  }

  @protected
  NativeVpnCommandResult commandSuccess() {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.success,
      permission: _permissionNotRequired(),
    );
  }

  @protected
  NativeVpnCommandResult commandFailed([String? message]) {
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
  try {
    final resPointer = _CoreLib()._lib.CGoInvoke(req);
    return _convertPointerToString(resPointer);
  } finally {
    calloc.free(req);
  }
}

Pointer<Char> _convertStringToPointer(String text) {
  final pointer = text.toNativeUtf8().cast<Char>();
  return pointer;
}

String _convertPointerToString(Pointer<Char> pointer) {
  if (pointer == nullptr) {
    throw StateError('CGoInvoke returned a null response');
  }
  try {
    return pointer.cast<Utf8>().toDartString();
  } finally {
    _CoreLib()._lib.CGoFree(pointer);
  }
}
