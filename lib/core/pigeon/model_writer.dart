import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:win32/win32.dart';

extension StartVpnRequestWriter on StartVpnRequest {
  Future<void> writeToStartFile() async {
    final data = JsonTool.encoder.convert(toJson());
    final filePath = VpnConstants.startPath;
    await Directory(File(filePath).parent.path).create(recursive: true);
    if (!Platform.isWindows) {
      await File(filePath).writeAsString(data, flush: true);
      return;
    }

    final temporary = File('$filePath.tmp');
    try {
      await temporary.writeAsString(data, flush: true);
      using((arena) {
        final result = MoveFileEx(
          arena.pcwstr(temporary.path),
          arena.pcwstr(filePath),
          MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
        );
        if (!result.value) {
          throw WindowsException(result.error.toHRESULT());
        }
      });
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
