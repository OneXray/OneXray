import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// The caller serializes writes to this target. Never delete the previous file
/// before replacement, including on Windows where rename differs from POSIX.
Future<void> writeBytesAtomically(File target, List<int> bytes) async {
  final staging = await target.parent.createTemp('.onexray-write-');
  final temporary = File('${staging.path}/payload');
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    if (Platform.isWindows) {
      using((arena) {
        final result = MoveFileEx(
          arena.pcwstr(temporary.path),
          arena.pcwstr(target.path),
          MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
        );
        if (!result.value) throw WindowsException(result.error.toHRESULT());
      });
    } else {
      await temporary.rename(target.path);
    }
  } finally {
    if (await temporary.exists()) await temporary.delete();
    await staging.delete();
  }
}
