import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

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
