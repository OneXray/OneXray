import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:onexray/core/ffi/generated_bindings.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

typedef WindowsNativeInvoker = Future<String> Function(String requestJson);

final class WindowsNativeException implements Exception {
  final String message;

  const WindowsNativeException(this.message);

  @override
  String toString() => message;
}

final class WindowsNativeApi {
  static const _maxHostResponseBytes = 1024 * 1024;
  static final _snapshotToken = RegExp(r'^vcore-session-v2:[0-9a-f]{64}$');
  static final WindowsNativeApi _singleton = WindowsNativeApi._(
    _invokeWindowsHostInWorker,
  );

  final WindowsNativeInvoker _hostInvoker;
  Future<void> _tail = Future<void>.value();

  factory WindowsNativeApi() => _singleton;

  WindowsNativeApi._(this._hostInvoker);

  factory WindowsNativeApi.forTest(WindowsNativeInvoker hostInvoker) =>
      WindowsNativeApi._(hostInvoker);

  Future<WindowsPackageEnvironment> getEnvironment() async {
    final data = await _invokeHost(WindowsNativeMethod.getEnvironment);
    final environment = _decodeModel(
      () => WindowsPackageEnvironment.fromJson(data),
      'invalid Windows package environment',
    );
    if (environment.packageFamilyName.isEmpty ||
        environment.packageLocalDataDir.isEmpty ||
        !p.isAbsolute(environment.packageLocalDataDir)) {
      throw const FormatException('invalid Windows package environment');
    }
    return environment;
  }

  Future<WindowsVpnProfileState> getVpnStatus() async =>
      _vpnState(await _invokeHost(WindowsNativeMethod.getVpnStatus));

  Future<WindowsVpnProfileState> startVpn(
    String configYaml,
    WindowsVpnNetworkSettings networkSettings, {
    WindowsSessionBackend? sessionBackend,
  }) async => _vpnState(
    await _invokeHost(
      WindowsNativeMethod.startVpn,
      WindowsStartVpnPayload(
        configYaml: configYaml,
        networkSettings: networkSettings,
        sessionBackend: sessionBackend,
      ).toJson(),
    ),
  );

  Future<WindowsVpnProfileState> stopVpn() async =>
      _vpnState(await _invokeHost(WindowsNativeMethod.stopVpn));

  Future<WindowsStartupTaskState> getStartupTaskStatus() async => _startupState(
    await _invokeHost(WindowsNativeMethod.getStartupTaskStatus),
  );

  Future<WindowsStartupTaskState> setStartupTaskEnabled(bool enabled) async =>
      _startupState(
        await _invokeHost(
          WindowsNativeMethod.setStartupTaskEnabled,
          WindowsSetStartupTaskEnabledPayload(enabled).toJson(),
        ),
      );

  Future<Map<String, dynamic>> _invokeHost(
    WindowsNativeMethod method, [
    Map<String, Object?> payload = const {},
  ]) {
    return _serial(() async {
      final request = WindowsNativeInvokeRequest(
        method: method,
        payload: payload,
      );
      final responseJson = await _hostInvoker(jsonEncode(request.toJson()));
      if (utf8.encode(responseJson).length > _maxHostResponseBytes) {
        throw const FormatException('Windows host response exceeds 1 MiB');
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(responseJson);
      } catch (_) {
        throw const FormatException('invalid Windows host response');
      }
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('invalid Windows host response');
      }
      final WindowsNativeInvokeResponse response;
      try {
        response = WindowsNativeInvokeResponse.fromJson(decoded);
      } catch (_) {
        throw const FormatException('invalid Windows host response');
      }
      if (!response.success) {
        if (response.data != null || response.error.isEmpty) {
          throw const FormatException('invalid Windows host failure response');
        }
        throw WindowsNativeException(response.error);
      }
      if (response.error.isNotEmpty || response.data == null) {
        throw const FormatException('invalid Windows host success response');
      }
      return response.data!;
    });
  }

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  static WindowsVpnProfileState _vpnState(Map<String, dynamic> data) {
    final state = _decodeModel(
      () => WindowsVpnProfileState.fromJson(data),
      'invalid Windows VPN state',
    );
    final token = state.snapshotToken;
    if (token != null && !_snapshotToken.hasMatch(token)) {
      throw const FormatException('invalid Windows snapshot token');
    }
    if (state.status != WindowsVpnStatus.disconnected && token == null) {
      throw const FormatException('active Windows VPN has no snapshot token');
    }
    return state;
  }

  static WindowsStartupTaskState _startupState(Map<String, dynamic> data) =>
      _decodeModel(
        () => WindowsStartupTaskStatus.fromJson(data),
        'invalid Windows StartupTask state',
      ).state;

  static T _decodeModel<T>(T Function() decode, String error) {
    try {
      return decode();
    } catch (_) {
      throw FormatException(error);
    }
  }
}

Future<String> _invokeWindowsHostInWorker(String requestJson) =>
    Isolate.run(() => _invokeDll(requestJson));

String _invokeDll(String requestJson) {
  final path = p.join(p.dirname(Platform.resolvedExecutable), 'vcore.dll');
  final bindings = NativeLibrary(DynamicLibrary.open(path));
  final request = requestJson.toNativeUtf8().cast<Char>();
  try {
    final response = bindings.VCoreWindowsVpnInvoke(request);
    if (response == nullptr) {
      throw const WindowsNativeException('VCoreWindowsVpnInvoke returned NULL');
    }
    try {
      return response.cast<Utf8>().toDartString();
    } finally {
      bindings.VCoreFree(response);
    }
  } finally {
    malloc.free(request);
  }
}

const _rasConnection = 1;
const _rasDisconnection = 2;
const _rasInvalidation = 0;

typedef _RasConnectionNotificationNative = Uint32 Function(
  Pointer<Void>,
  Pointer<Void>,
  Uint32,
);
typedef _RasConnectionNotificationDart = int Function(
  Pointer<Void>,
  Pointer<Void>,
  int,
);

Stream<void> watchWindowsVpnInvalidations() async* {
  if (!Platform.isWindows) {
    throw UnsupportedError('Windows VPN status observation requires Windows');
  }

  final stopResult = CreateEvent(null, true, false, null);
  final stopEvent = stopResult.value;
  if (!stopEvent.isValid) {
    throw StateError('CreateEventW failed: ${stopResult.error.code}');
  }

  final messages = ReceivePort();
  final exited = ReceivePort();
  Isolate? worker;
  try {
    worker = await Isolate.spawn(
      _watchRasConnections,
      (messages.sendPort, stopEvent.address),
      onError: messages.sendPort,
      onExit: exited.sendPort,
    );
    yield* messages
        .where((message) {
          if (message is String) {
            throw StateError(message);
          }
          if (message is List && message.isNotEmpty) {
            throw StateError(message.first.toString());
          }
          return message == _rasInvalidation;
        })
        .map<void>((_) {});
  } finally {
    if (worker != null) {
      if (!SetEvent(stopEvent).value) {
        worker.kill(priority: Isolate.immediate);
      }
      try {
        await exited.first.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        worker.kill(priority: Isolate.immediate);
      }
    }
    messages.close();
    exited.close();
    stopEvent.close();
  }
}

void _watchRasConnections((SendPort, int) input) {
  final (output, stopAddress) = input;
  HANDLE? changeEvent;
  Pointer<Pointer<Void>>? handles;
  try {
    final changeResult = CreateEvent(null, false, false, null);
    changeEvent = changeResult.value;
    if (!changeEvent.isValid) {
      throw StateError('CreateEventW failed: ${changeResult.error.code}');
    }

    final notify = DynamicLibrary.open('rasapi32.dll')
        .lookupFunction<
          _RasConnectionNotificationNative,
          _RasConnectionNotificationDart
        >('RasConnectionNotificationW');
    final result = notify(
      Pointer<Void>.fromAddress(-1),
      Pointer<Void>.fromAddress(changeEvent.address),
      _rasConnection | _rasDisconnection,
    );
    if (result != 0) {
      throw StateError('RasConnectionNotificationW failed: $result');
    }

    final stopEvent = HANDLE(Pointer.fromAddress(stopAddress));
    handles = calloc<Pointer<Void>>(2);
    handles[0] = Pointer<Void>.fromAddress(changeEvent.address);
    handles[1] = Pointer<Void>.fromAddress(stopEvent.address);
    output.send(_rasInvalidation);

    while (true) {
      final wait = WaitForMultipleObjects(2, handles.cast(), false, INFINITE);
      if (wait.value == WAIT_OBJECT_0) {
        output.send(_rasInvalidation);
      } else if (wait.value == const WAIT_EVENT(1)) {
        return;
      } else {
        throw StateError('WaitForMultipleObjects failed: ${wait.error.code}');
      }
    }
  } catch (error, stackTrace) {
    output.send('$error\n$stackTrace');
  } finally {
    if (handles != null) {
      calloc.free(handles);
    }
    changeEvent?.close();
  }
}
