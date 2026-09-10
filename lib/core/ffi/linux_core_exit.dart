import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:onexray/core/ffi/desktop_core_exit.dart';

final _libc = DynamicLibrary.open('libc.so.6');
final _syscall = _libc
    .lookupFunction<
      Long Function(Long, VarArgs<(Int32, Uint32)>),
      int Function(int, int, int)
    >('syscall');
final _eventfd = _libc
    .lookupFunction<Int32 Function(Uint32, Int32), int Function(int, int)>(
      'eventfd',
    );
final _close = _libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
  'close',
);
final _write = _libc
    .lookupFunction<
      IntPtr Function(Int32, Pointer<Void>, UintPtr),
      int Function(int, Pointer<Void>, int)
    >('write');
final _poll = _libc
    .lookupFunction<
      Int32 Function(Pointer<_PollFd>, UnsignedLong, Int32),
      int Function(Pointer<_PollFd>, int, int)
    >('poll');
final _errno = _libc
    .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
      '__errno_location',
    );

final class _PollFd extends Struct {
  @Int32()
  external int fd;
  @Int16()
  external int events;
  @Int16()
  external int revents;
}

/// Linux x64/arm64 use SYS_pidfd_open = 434. poll(-1) sleeps in the kernel;
/// it does not repeatedly query process state. Requires Linux 5.3 or newer.
DesktopCoreExitWatch watchLinuxCoreExit(int pid) {
  final errno = _errno();
  final pidfd = _syscall(434, pid, 0);
  if (pidfd < 0) {
    final error = errno.value;
    if (error == 3) return DesktopCoreExitWatch(Future.value(true), () {});
    throw OSError(
      'pidfd_open failed; Core exit notifications require Linux 5.3+',
      error,
    );
  }
  final cancelFd = _eventfd(0, 0x80000 | 0x800); // CLOEXEC | NONBLOCK
  if (cancelFd < 0) {
    final error = errno.value;
    _close(pidfd);
    throw OSError('eventfd failed', error);
  }
  var closed = false;
  var cancelled = false;
  final exited = _wait(pidfd, cancelFd).whenComplete(() {
    closed = true;
    _close(pidfd);
    _close(cancelFd);
  });
  return DesktopCoreExitWatch(exited, () {
    if (closed || cancelled) return;
    cancelled = true;
    using((arena) {
      final value = arena<Uint64>()..value = 1;
      final errno = _errno();
      while (_write(cancelFd, value.cast(), 8) < 0) {
        final error = errno.value;
        if (error == 4) continue; // EINTR
        throw OSError('Could not cancel Core exit notification', error);
      }
    });
  });
}

Future<bool> _wait(int pidfd, int cancelFd) => Isolate.run(
  () => using((arena) {
    final errno = _errno();
    final fds = arena<_PollFd>(2);
    fds[0]
      ..fd = pidfd
      ..events = 1; // POLLIN
    fds[1]
      ..fd = cancelFd
      ..events = 1;
    while (true) {
      if (_poll(fds, 2, -1) < 0) {
        final error = errno.value;
        if (error == 4) continue;
        throw OSError('Core exit notification failed', error);
      }
      if (fds[1].revents != 0) return false;
      if (fds[0].revents & (1 | 0x10) != 0) return true; // POLLIN | POLLHUP
      throw StateError('Unexpected pidfd event: ${fds[0].revents}');
    }
  }),
);
