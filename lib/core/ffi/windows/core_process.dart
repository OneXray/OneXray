import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:onexray/core/ffi/desktop_core_process.dart';
import 'package:onexray/core/ffi/desktop_core_exit.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// Win32 work (including the UAC prompt) never blocks the Flutter isolate.
class WindowsCoreProcess {
  DesktopCoreExitWatch watchExit(
    DesktopCoreProcessRecord record,
    String executable,
  ) {
    final created = CreateEvent(null, true, false, null);
    if (!created.value.isValid) _failed('CreateEvent', created.error);
    final cancelEvent = created.value;
    var closed = false;
    final exited = _waitForExit(record, executable, cancelEvent.address)
        .whenComplete(() {
          closed = true;
          CloseHandle(cancelEvent);
        });
    return DesktopCoreExitWatch(exited, () {
      if (!closed) SetEvent(cancelEvent);
    });
  }

  Future<DesktopCoreProcessRecord> start(
    String executable,
    List<String> arguments,
    String configPath,
  ) => Isolate.run(() {
    final handle = _launchElevated(executable, arguments);
    try {
      final pid = GetProcessId(handle);
      if (pid.value == 0) _failed('GetProcessId', pid.error);
      return DesktopCoreProcessRecord(
        pid: pid.value,
        configPath: configPath,
        startTicks: _creationTime(handle),
      );
    } catch (_) {
      _terminate(handle);
      rethrow;
    } finally {
      CloseHandle(handle);
    }
  });

  Future<bool> isRunning(DesktopCoreProcessRecord record, String executable) =>
      Isolate.run(() {
        final handle = _openOwned(record, executable);
        if (handle == null) return false;
        CloseHandle(handle);
        return true;
      });

  Future<void> stop(DesktopCoreProcessRecord record, String executable) =>
      Isolate.run(() {
        final handle = _openOwned(record, executable, terminate: true);
        if (handle == null) return;
        try {
          _terminate(handle);
        } finally {
          CloseHandle(handle);
        }
      });
}

Future<bool> _waitForExit(
  DesktopCoreProcessRecord record,
  String executable,
  int cancelAddress,
) => Isolate.run(() {
  final process = _openOwned(record, executable);
  if (process == null) return true;
  try {
    return using((arena) {
      final handles = arena<Pointer>(2);
      handles[0] = process;
      handles[1] = Pointer.fromAddress(cancelAddress);
      final result = WaitForMultipleObjects(2, handles, false, INFINITE);
      if (result.value == WAIT_OBJECT_0) return true;
      if (result.value == WAIT_EVENT(WAIT_OBJECT_0 + 1)) return false;
      _failed('WaitForMultipleObjects', result.error);
    });
  } finally {
    CloseHandle(process);
  }
});

/// ShellExecuteEx takes a command-line string, not an argv array.
String quoteWindowsArgument(String value) {
  final escaped = value.replaceAllMapped(
    RegExp(r'(\\*)"'),
    (match) => '${'\\' * (match[1]!.length * 2 + 1)}"',
  );
  return '"${escaped.replaceAllMapped(RegExp(r'\\+$'), (match) => '\\' * (match[0]!.length * 2))}"';
}

HANDLE _launchElevated(String executable, List<String> arguments) {
  final initialized = CoInitializeEx(COINIT_APARTMENTTHREADED);
  if (initialized.isError) throw WindowsException(initialized);
  try {
    return using((arena) {
      final info = arena<SHELLEXECUTEINFO>();
      info.ref
        ..cbSize = sizeOf<SHELLEXECUTEINFO>()
        ..fMask =
            0x40 |
            0x100 // NOCLOSEPROCESS | NOASYNC
        ..lpVerb = arena.pwstr('runas')
        ..lpFile = arena.pwstr(executable)
        ..lpDirectory = arena.pwstr(p.windows.dirname(executable))
        ..lpParameters = arena.pwstr(
          arguments.map(quoteWindowsArgument).join(' '),
        )
        ..nShow = SW_HIDE;
      final result = ShellExecuteEx(info);
      if (!result.value || !info.ref.hProcess.isValid) {
        _failed('ShellExecuteEx', result.error);
      }
      return info.ref.hProcess;
    });
  } finally {
    CoUninitialize();
  }
}

HANDLE? _openOwned(
  DesktopCoreProcessRecord record,
  String executable, {
  bool terminate = false,
}) {
  if (record.pid <= 0) throw StateError('Invalid Windows Core PID');
  final rights = PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE;
  var opened = OpenProcess(
    terminate ? rights | PROCESS_TERMINATE : rights,
    false,
    record.pid,
  );
  if (!opened.value.isValid && terminate) {
    opened = OpenProcess(rights, false, record.pid);
  }
  if (!opened.value.isValid) {
    if (opened.error == ERROR_INVALID_PARAMETER) return null; // Exited.
    _failed('OpenProcess', opened.error);
  }
  final handle = opened.value;
  try {
    if (!_running(handle) ||
        (record.startTicks != null &&
            _creationTime(handle) != record.startTicks)) {
      CloseHandle(handle);
      return null; // The recorded process exited; never act on a reused PID.
    }
    using((arena) {
      final actualPath = arena.pwstrBuffer(32768);
      final length = arena<Uint32>()..value = 32768;
      final image = QueryFullProcessImageName(
        handle,
        PROCESS_NAME_FORMAT(0),
        actualPath,
        length,
      );
      if (!image.value) _failed('QueryFullProcessImageName', image.error);
      // Released v26.8.4 stored only the PID and kept Core under bin/.
      final legacy = record.startTicks == null && record.configPath == null;
      final expected = legacy
          ? p.windows.join(
              p.windows.dirname(executable),
              'bin',
              'OneXrayCore.exe',
            )
          : executable;
      if (!p.windows.equals(actualPath.toDartString(), expected)) {
        throw StateError('Windows Core process ownership does not match');
      }
      final session = arena<Uint32>();
      final currentSession = arena<Uint32>();
      final a = ProcessIdToSessionId(record.pid, session);
      final b = ProcessIdToSessionId(GetCurrentProcessId(), currentSession);
      if (!a.value || !b.value || session.value != currentSession.value) {
        throw StateError('Windows Core belongs to another session');
      }
    });
    return handle;
  } catch (_) {
    CloseHandle(handle);
    rethrow;
  }
}

int _creationTime(HANDLE handle) => using((arena) {
  final created = arena<FILETIME>();
  final result = GetProcessTimes(
    handle,
    created,
    arena<FILETIME>(),
    arena<FILETIME>(),
    arena<FILETIME>(),
  );
  if (!result.value) _failed('GetProcessTimes', result.error);
  return (created.ref.dwHighDateTime << 32) | created.ref.dwLowDateTime;
});

bool _running(HANDLE handle) {
  final result = WaitForSingleObject(handle, 0);
  return switch (result.value) {
    WAIT_OBJECT_0 => false,
    WAIT_TIMEOUT => true,
    _ => _failed('WaitForSingleObject', result.error),
  };
}

void _terminate(HANDLE handle) {
  if (!_running(handle)) return;
  final result = TerminateProcess(handle, 0);
  if (!result.value && _running(handle)) {
    final pid = GetProcessId(handle);
    if (pid.value == 0) _failed('GetProcessId', pid.error);
    final systemDirectory = using((arena) {
      final buffer = arena.pwstrBuffer(32768);
      final result = GetSystemDirectory(buffer, 32768);
      if (result.value == 0 || result.value >= 32768) {
        _failed('GetSystemDirectory', result.error);
      }
      return buffer.toDartString();
    });
    final taskkill = _launchElevated(
      p.windows.join(systemDirectory, 'taskkill.exe'),
      ['/PID', '${pid.value}', '/T', '/F'],
    );
    try {
      if (WaitForSingleObject(taskkill, 5000).value != WAIT_OBJECT_0) {
        throw StateError('Timed out waiting for elevated Core termination');
      }
    } finally {
      CloseHandle(taskkill);
    }
  }
  if (WaitForSingleObject(handle, 3000).value != WAIT_OBJECT_0) {
    throw StateError('Windows Core did not stop');
  }
}

Never _failed(String operation, Object error) =>
    throw StateError('$operation failed: $error');
