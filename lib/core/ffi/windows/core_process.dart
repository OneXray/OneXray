import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:onexray/core/ffi/desktop_core_exit.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

/// Discovery, UAC and exit waits run off the Flutter isolate.
class WindowsCoreProcess {
  final String _name;

  WindowsCoreProcess() : _name = 'OneXrayCore.exe';

  @visibleForTesting
  WindowsCoreProcess.forTesting({required String processName})
    : _name = processName;

  Future<Set<int>> findPids() => Isolate.run(() => _namedPids(_name));

  Future<void> stopAll() => Isolate.run(() => _stopNamed(_name));

  DesktopCoreExitWatch watchExit(int pid) {
    final created = CreateEvent(null, true, false, null);
    if (!created.value.isValid) _failed('CreateEvent', created.error);
    final cancelEvent = created.value;
    var closed = false;
    final exited = _waitForExit(pid, _name, cancelEvent.address).whenComplete(
      () {
        closed = true;
        CloseHandle(cancelEvent);
      },
    );
    return DesktopCoreExitWatch(exited, () {
      if (!closed) SetEvent(cancelEvent);
    });
  }

  Future<int> start(String executable, List<String> arguments) =>
      Isolate.run(() {
        final handle = _launchElevated(executable, arguments);
        try {
          final pid = GetProcessId(handle);
          if (pid.value == 0) _failed('GetProcessId', pid.error);
          return pid.value;
        } catch (_) {
          _stopNamed(_name);
          rethrow;
        } finally {
          CloseHandle(handle);
        }
      });
}

Future<bool> _waitForExit(int pid, String name, int cancelAddress) =>
    Isolate.run(() {
      final process = _openNamed(pid, name);
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

// Query names directly: no executable-path, owner or session lookup is needed.
Set<int> _namedPids(String name) => using((arena) {
  const initialSnapshotBytes = 64 * 1024;
  const maxSnapshotBytes = 64 * 1024 * 1024;
  final required = arena<Uint32>();
  var capacity = initialSnapshotBytes;
  while (capacity <= maxSnapshotBytes) {
    final buffer = calloc<Uint8>(capacity);
    try {
      final status = NtQuerySystemInformation(
        SystemProcessInformation,
        buffer,
        capacity,
        required,
      );
      if (status == STATUS_INFO_LENGTH_MISMATCH) {
        capacity = required.value > capacity
            ? required.value + initialSnapshotBytes
            : capacity * 2;
        continue;
      }
      if (status.isError) throw WindowsException(status.toHRESULT());
      final pids = <int>{};
      var offset = 0;
      while (true) {
        if (offset + sizeOf<SYSTEM_PROCESS_INFORMATION>() > required.value ||
            required.value > capacity) {
          throw StateError('Invalid Windows process snapshot');
        }
        final entry = (buffer + offset).cast<SYSTEM_PROCESS_INFORMATION>().ref;
        final image = entry.ImageName;
        if (image.Length > 0) {
          final start = image.Buffer.address - buffer.address;
          if (image.Length.isOdd ||
              start < 0 ||
              start + image.Length > required.value) {
            throw StateError('Invalid Windows process name');
          }
          if (entry.NumberOfThreads > 0 &&
              image.Buffer.toDartString(length: image.Length ~/ 2)
                      .toLowerCase() ==
                  name.toLowerCase()) {
            pids.add(entry.UniqueProcessId.address);
          }
        }
        if (entry.NextEntryOffset == 0) return pids;
        if (entry.NextEntryOffset < sizeOf<SYSTEM_PROCESS_INFORMATION>()) {
          throw StateError('Invalid Windows process snapshot offset');
        }
        offset += entry.NextEntryOffset;
      }
    } finally {
      calloc.free(buffer);
    }
  }
  throw StateError('Windows process snapshot exceeds the size limit');
});

void _stopNamed(String name) {
  final handles = <int, HANDLE>{};
  var elevate = false;
  try {
    for (final pid in _namedPids(name)) {
      final opened = OpenProcess(PROCESS_TERMINATE | SYNCHRONIZE, false, pid);
      if (opened.value.isValid) {
        handles[pid] = opened.value;
      } else if (_namedPids(name).contains(pid)) {
        if (opened.error != ERROR_ACCESS_DENIED) {
          _failed('OpenProcess', opened.error);
        }
        elevate = true;
      }
    }
    if (handles.isNotEmpty) {
      // Recheck names after opening handles so a reused PID cannot select an
      // unrelated process. Handles, not cached PIDs, are used for termination.
      final current = _namedPids(name);
      for (final entry in handles.entries.toList()) {
        if (!current.contains(entry.key)) {
          CloseHandle(handles.remove(entry.key)!);
          continue;
        }
        if (elevate || !_running(entry.value)) continue;
        final killed = TerminateProcess(entry.value, 0);
        if (!killed.value && _running(entry.value)) {
          if (killed.error != ERROR_ACCESS_DENIED) {
            _failed('TerminateProcess', killed.error);
          }
          elevate = true;
        }
      }
    }
    if (elevate) {
      final taskkill = _launchElevated(
        p.windows.join(_systemDirectory(), 'taskkill.exe'),
        ['/IM', name, '/F'],
      );
      try {
        final waited = WaitForSingleObject(taskkill, 5000);
        if (waited.value == WAIT_TIMEOUT) {
          throw StateError('Timed out waiting for elevated Core termination');
        }
        if (waited.value != WAIT_OBJECT_0) {
          _failed('WaitForSingleObject', waited.error);
        }
        final exitCode = using((arena) {
          final code = arena<Uint32>();
          final result = GetExitCodeProcess(taskkill, code);
          if (!result.value) _failed('GetExitCodeProcess', result.error);
          return code.value;
        });
        // No targets is also possible when a Core exits during the UAC prompt.
        if (exitCode != 0 && _namedPids(name).isNotEmpty) {
          throw StateError('Elevated Core termination failed: $exitCode');
        }
      } finally {
        CloseHandle(taskkill);
      }
    }
    final waiting = Stopwatch()..start();
    while (true) {
      if (_namedPids(name).isEmpty && !handles.values.any(_running)) return;
      if (waiting.elapsed >= const Duration(seconds: 3)) {
        throw StateError('Windows Core did not stop');
      }
      sleep(const Duration(milliseconds: 50));
    }
  } finally {
    for (final handle in handles.values) {
      CloseHandle(handle);
    }
  }
}

String _systemDirectory() => using((arena) {
  final buffer = arena.pwstrBuffer(32768);
  final result = GetSystemDirectory(buffer, 32768);
  if (result.value == 0 || result.value >= 32768) {
    _failed('GetSystemDirectory', result.error);
  }
  return buffer.toDartString();
});

HANDLE? _openNamed(int pid, String name) {
  if (pid <= 0) throw StateError('Invalid Windows Core PID');
  final opened = OpenProcess(PROCESS_ACCESS_RIGHTS(SYNCHRONIZE), false, pid);
  if (!opened.value.isValid) {
    // Exiting processes can disappear before OpenProcess. Only a fresh name
    // query proves this race; other failures must not masquerade as an exit.
    if (!_namedPids(name).contains(pid)) return null;
    _failed('OpenProcess', opened.error);
  }
  final handle = opened.value;
  try {
    if (!_running(handle) || !_namedPids(name).contains(pid)) {
      CloseHandle(handle);
      return null;
    }
    return handle;
  } catch (_) {
    CloseHandle(handle);
    rethrow;
  }
}

bool _running(HANDLE handle) {
  final result = WaitForSingleObject(handle, 0);
  return switch (result.value) {
    WAIT_OBJECT_0 => false,
    WAIT_TIMEOUT => true,
    _ => _failed('WaitForSingleObject', result.error),
  };
}

Never _failed(String operation, Object error) =>
    throw StateError('$operation failed: $error');
