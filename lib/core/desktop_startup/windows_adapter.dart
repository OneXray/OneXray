import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:onexray/core/desktop_startup/adapter.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:win32/win32.dart';

final class WindowsLaunchAtLoginAdapter extends LaunchAtLoginAdapter {
  static const _runKey = r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const _valueName = 'OneXray';

  final String _executable;

  WindowsLaunchAtLoginAdapter({String? executable})
    : _executable = executable ?? Platform.resolvedExecutable;

  @override
  Future<LaunchAtLoginStatus> query() async {
    try {
      final command = _readCommand();
      if (command == null) {
        return const LaunchAtLoginStatus.disabled();
      }
      if (command != commandForExecutable(_executable) ||
          !File(_executable).existsSync()) {
        return const LaunchAtLoginStatus.disabled(
          message: 'The existing startup registry entry is stale.',
        );
      }
      return const LaunchAtLoginStatus.enabled();
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  @override
  Future<LaunchAtLoginStatus> setEnabled(bool enabled) async {
    try {
      if (enabled) {
        if (!File(_executable).existsSync()) {
          return const LaunchAtLoginStatus.error(
            'The OneXray executable does not exist.',
          );
        }
        _writeCommand(commandForExecutable(_executable));
      } else {
        _deleteCommand();
      }
      return query();
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  static String commandForExecutable(String executable) {
    return quoteCommandLineArgument(executable);
  }

  static String quoteCommandLineArgument(String value) {
    final result = StringBuffer('"');
    var backslashes = 0;
    for (final codeUnit in value.codeUnits) {
      if (codeUnit == 0x5c) {
        backslashes++;
        continue;
      }
      if (codeUnit == 0x22) {
        result.write('\\' * (backslashes * 2 + 1));
        result.write('"');
      } else {
        result.write('\\' * backslashes);
        result.writeCharCode(codeUnit);
      }
      backslashes = 0;
    }
    result.write('\\' * (backslashes * 2));
    result.write('"');
    return result.toString();
  }

  String? _readCommand() {
    return using((arena) {
      final subKey = arena.pcwstr(_runKey);
      final valueName = arena.pcwstr(_valueName);
      final size = arena<Uint32>();
      final sizeResult = RegGetValue(
        HKEY_CURRENT_USER,
        subKey,
        valueName,
        RRF_RT_REG_SZ,
        null,
        null,
        size,
      );
      if (sizeResult == ERROR_FILE_NOT_FOUND) {
        return null;
      }
      sizeResult.onSuccess(() {});

      final data = arena<Uint8>(size.value);
      RegGetValue(
        HKEY_CURRENT_USER,
        subKey,
        valueName,
        RRF_RT_REG_SZ,
        null,
        data,
        size,
      ).onSuccess(() {});
      return data.cast<Utf16>().toDartString();
    });
  }

  void _writeCommand(String command) {
    using((arena) {
      final subKey = arena.pcwstr(_runKey);
      final keyPointer = arena<Pointer>();
      RegCreateKeyEx(
        HKEY_CURRENT_USER,
        subKey,
        null,
        REG_OPTION_NON_VOLATILE,
        KEY_SET_VALUE,
        null,
        keyPointer,
        null,
      ).onSuccess(() {});

      final key = HKEY(keyPointer.value);
      try {
        final valueName = arena.pcwstr(_valueName);
        final data = command.toNativeUtf16(allocator: arena);
        RegSetValueEx(
          key,
          valueName,
          REG_SZ,
          data.cast<Uint8>(),
          (command.codeUnits.length + 1) * sizeOf<Uint16>(),
        ).onSuccess(() {});
      } finally {
        RegCloseKey(key);
      }
    });
  }

  void _deleteCommand() {
    using((arena) {
      final subKey = arena.pcwstr(_runKey);
      final valueName = arena.pcwstr(_valueName);
      final result = RegDeleteKeyValue(HKEY_CURRENT_USER, subKey, valueName);
      if (result != ERROR_FILE_NOT_FOUND) {
        result.onSuccess(() {});
      }
    });
  }
}
