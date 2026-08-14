import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:onexray/core/desktop_startup/adapter.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

final class WindowsStartupShortcut {
  final String target;
  final String workingDirectory;
  final String arguments;

  const WindowsStartupShortcut({
    required this.target,
    required this.workingDirectory,
    required this.arguments,
  });
}

abstract interface class WindowsLaunchAtLoginStore {
  bool shortcutExists();

  WindowsStartupShortcut? readShortcut();

  void writeShortcut({
    required String target,
    required String workingDirectory,
    required String arguments,
  });

  void deleteShortcut();
}

final class WindowsLaunchAtLoginAdapter extends LaunchAtLoginAdapter {
  final String _executable;
  final WindowsLaunchAtLoginStore _store;

  WindowsLaunchAtLoginAdapter({
    String? executable,
    WindowsLaunchAtLoginStore? store,
  }) : _executable = executable ?? Platform.resolvedExecutable,
       _store = store ?? Win32WindowsLaunchAtLoginStore();

  @override
  Future<LaunchAtLoginStatus> query() async {
    try {
      WindowsStartupShortcut? shortcut;
      if (_store.shortcutExists()) {
        try {
          shortcut = _store.readShortcut();
        } catch (error, stackTrace) {
          ygLogger('read startup shortcut failed: $error\n$stackTrace');
          return LaunchAtLoginStatus.error(
            'The existing startup shortcut cannot be read: $error',
          );
        }
      }

      if (_isValidCurrentShortcut(shortcut)) {
        if (File(_executable).existsSync()) {
          return const LaunchAtLoginStatus.enabled();
        }
        return const LaunchAtLoginStatus.disabled(
          message: 'The existing startup shortcut is stale.',
        );
      }

      if (shortcut != null) {
        return const LaunchAtLoginStatus.disabled(
          message: 'The existing startup shortcut is stale.',
        );
      }
      return const LaunchAtLoginStatus.disabled();
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  @override
  Future<LaunchAtLoginStatus> setEnabled(bool enabled) async {
    try {
      if (enabled) {
        return await _enable();
      }
      return await _disable();
    } catch (error) {
      return LaunchAtLoginStatus.error(error.toString());
    }
  }

  Future<LaunchAtLoginStatus> _enable() async {
    if (!File(_executable).existsSync()) {
      return const LaunchAtLoginStatus.error(
        'The OneXray executable does not exist.',
      );
    }

    WindowsStartupShortcut? existingShortcut;
    if (_store.shortcutExists()) {
      try {
        existingShortcut = _store.readShortcut();
      } catch (error, stackTrace) {
        ygLogger('read startup shortcut failed: $error\n$stackTrace');
        return LaunchAtLoginStatus.error(
          'The existing startup shortcut cannot be read: $error',
        );
      }
    }
    if (existingShortcut != null && !_canReplaceShortcut(existingShortcut)) {
      return const LaunchAtLoginStatus.error(
        'The OneXray startup shortcut belongs to another executable.',
      );
    }
    if (!_isValidCurrentShortcut(existingShortcut)) {
      _replaceShortcut(existingShortcut);
    }
    return query();
  }

  Future<LaunchAtLoginStatus> _disable() async {
    WindowsStartupShortcut? existingShortcut;
    if (_store.shortcutExists()) {
      try {
        existingShortcut = _store.readShortcut();
      } catch (error, stackTrace) {
        ygLogger('read startup shortcut failed: $error\n$stackTrace');
        return LaunchAtLoginStatus.error(
          'The existing startup shortcut cannot be read: $error',
        );
      }
    }
    if (existingShortcut != null && _canReplaceShortcut(existingShortcut)) {
      _store.deleteShortcut();
    }

    return query();
  }

  void _replaceShortcut(WindowsStartupShortcut? previousShortcut) {
    try {
      _writeShortcut();
    } catch (_) {
      try {
        if (previousShortcut == null) {
          _store.deleteShortcut();
        } else {
          _writeShortcutEntry(previousShortcut);
        }
      } catch (rollbackError, stackTrace) {
        ygLogger(
          'rollback startup shortcut replacement failed: '
          '$rollbackError\n$stackTrace',
        );
      }
      rethrow;
    }
  }

  void _writeShortcut() {
    _store.writeShortcut(
      target: _executable,
      workingDirectory: path.windows.dirname(_executable),
      arguments: '',
    );
  }

  void _writeShortcutEntry(WindowsStartupShortcut shortcut) {
    _store.writeShortcut(
      target: shortcut.target,
      workingDirectory: shortcut.workingDirectory,
      arguments: shortcut.arguments,
    );
  }

  bool _hasCurrentTarget(WindowsStartupShortcut? shortcut) {
    return shortcut != null &&
        path.windows.equals(shortcut.target, _executable);
  }

  bool _isValidCurrentShortcut(WindowsStartupShortcut? shortcut) {
    return _hasCurrentTarget(shortcut) &&
        path.windows.equals(
          shortcut!.workingDirectory,
          path.windows.dirname(_executable),
        ) &&
        shortcut.arguments.isEmpty;
  }

  bool _canReplaceShortcut(WindowsStartupShortcut? shortcut) {
    if (shortcut == null ||
        shortcut.target.trim().isEmpty ||
        _hasCurrentTarget(shortcut)) {
      return true;
    }
    return _isMissingOneXrayExecutable(shortcut.target);
  }

  static bool _isMissingOneXrayExecutable(String executable) {
    return path.windows.basename(executable).toLowerCase() == 'onexray.exe' &&
        !File(executable).existsSync();
  }
}

final class Win32WindowsLaunchAtLoginStore
    implements WindowsLaunchAtLoginStore {
  static const _shortcutName = 'OneXray.lnk';
  static const _pathBufferLength = 32768;
  static const _shellLinkGetPathRaw = 0x4;

  final String? _shortcutPathOverride;

  Win32WindowsLaunchAtLoginStore({String? shortcutPath})
    : _shortcutPathOverride = shortcutPath;

  late final String shortcutPath =
      _shortcutPathOverride ?? _resolveStartupShortcutPath();

  @override
  bool shortcutExists() => File(shortcutPath).existsSync();

  @override
  WindowsStartupShortcut? readShortcut() {
    if (!shortcutExists()) {
      return null;
    }

    return _withSta(() {
      return using((arena) {
        final shellLink = _createShellLink(arena);
        final persistFile = arena.adopt(
          shellLink.queryInterface<IPersistFile>(),
        );
        persistFile.load(
          arena.pcwstr(shortcutPath),
          STGM_READ | STGM_SHARE_DENY_WRITE,
        );

        final target = arena.pwstrBuffer(_pathBufferLength);
        final workingDirectory = arena.pwstrBuffer(_pathBufferLength);
        final arguments = arena.pwstrBuffer(_pathBufferLength);
        shellLink.getPath(
          target,
          _pathBufferLength,
          nullptr.cast<WIN32_FIND_DATA>(),
          _shellLinkGetPathRaw,
        );
        shellLink.getWorkingDirectory(workingDirectory, _pathBufferLength);
        shellLink.getArguments(arguments, _pathBufferLength);

        return WindowsStartupShortcut(
          target: target.toDartString(),
          workingDirectory: workingDirectory.toDartString(),
          arguments: arguments.toDartString(),
        );
      });
    });
  }

  @override
  void writeShortcut({
    required String target,
    required String workingDirectory,
    required String arguments,
  }) {
    Directory(path.windows.dirname(shortcutPath)).createSync(recursive: true);
    _withSta(() {
      using((arena) {
        final shellLink = _createShellLink(arena);
        shellLink.setPath(arena.pcwstr(target));
        shellLink.setWorkingDirectory(arena.pcwstr(workingDirectory));
        shellLink.setArguments(arena.pcwstr(arguments));
        shellLink.setDescription(arena.pcwstr('OneXray'));
        shellLink.setIconLocation(arena.pcwstr(target), 0);
        shellLink.setShowCmd(SW_SHOWNORMAL);

        final persistFile = arena.adopt(
          shellLink.queryInterface<IPersistFile>(),
        );
        persistFile.save(arena.pcwstr(shortcutPath), true);
      });
    });
  }

  @override
  void deleteShortcut() {
    final shortcut = File(shortcutPath);
    if (shortcut.existsSync()) {
      shortcut.deleteSync();
    }
  }

  static IShellLink _createShellLink(Arena arena) {
    return arena.adopt(
      CoCreateInstance<IShellLink>(
        ShellLink.toNative(allocator: arena),
        null,
        CLSCTX_INPROC_SERVER,
      ),
    );
  }

  static String _resolveStartupShortcutPath() {
    return using((arena) {
      final startupFolder = SHGetKnownFolderPath(
        FOLDERID_Startup.toNative(allocator: arena),
        KF_FLAG_CREATE,
        null,
      );
      try {
        return path.windows.join(startupFolder.toDartString(), _shortcutName);
      } finally {
        CoTaskMemFree(startupFolder);
      }
    });
  }

  static T _withSta<T>(T Function() operation) {
    final result = CoInitializeEx(COINIT_APARTMENTTHREADED);
    if (result.isError) {
      throw WindowsException(result);
    }
    try {
      return operation();
    } finally {
      CoUninitialize();
    }
  }
}
