import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/desktop_startup/windows_exe_adapter.dart';
import 'package:path/path.dart' as path;

void main() {
  test('reports a missing startup shortcut as disabled', () async {
    final store = _FakeWindowsLaunchAtLoginStore();
    final adapter = WindowsExeLaunchAtLoginAdapter(store: store);

    final result = await adapter.query();

    expect(result.state.name, 'disabled');
    expect(result.message, isNull);
    expect(store.shortcut, isNull);
  });

  test('reports the current Startup Folder shortcut as enabled', () async {
    final executable = Platform.resolvedExecutable;
    final store = _FakeWindowsLaunchAtLoginStore(
      shortcut: _shortcut(executable.toUpperCase()),
    );
    final adapter = WindowsExeLaunchAtLoginAdapter(
      executable: executable,
      store: store,
    );

    final result = await adapter.query();

    expect(result.enabled, isTrue);
  });

  test('enabling writes one Startup Folder shortcut', () async {
    final executable = Platform.resolvedExecutable;
    final store = _FakeWindowsLaunchAtLoginStore();
    final adapter = WindowsExeLaunchAtLoginAdapter(
      executable: executable,
      store: store,
    );

    final result = await adapter.setEnabled(true);

    expect(result.enabled, isTrue);
    expect(store.shortcut?.target, executable);
    expect(store.shortcut?.workingDirectory, path.windows.dirname(executable));
    expect(store.shortcut?.arguments, isEmpty);
  });

  test('disabling removes the current startup shortcut', () async {
    final executable = Platform.resolvedExecutable;
    final store = _FakeWindowsLaunchAtLoginStore(
      shortcut: _shortcut(executable),
    );
    final adapter = WindowsExeLaunchAtLoginAdapter(
      executable: executable,
      store: store,
    );

    final result = await adapter.setEnabled(false);

    expect(result.enabled, isFalse);
    expect(store.shortcut, isNull);
  });

  test('disabling preserves a shortcut owned by another copy', () async {
    final executable = Platform.resolvedExecutable;
    final otherExecutable = _createOtherOneXrayExecutable();
    final store = _FakeWindowsLaunchAtLoginStore(
      shortcut: _shortcut(otherExecutable),
    );
    final adapter = WindowsExeLaunchAtLoginAdapter(
      executable: executable,
      store: store,
    );

    final result = await adapter.setEnabled(false);

    expect(result.enabled, isFalse);
    expect(store.shortcut?.target, otherExecutable);
  });

  test('enabling does not overwrite another shortcut target', () async {
    final executable = Platform.resolvedExecutable;
    final otherExecutable = _createOtherOneXrayExecutable();
    final store = _FakeWindowsLaunchAtLoginStore(
      shortcut: _shortcut(otherExecutable),
    );
    final adapter = WindowsExeLaunchAtLoginAdapter(
      executable: executable,
      store: store,
    );

    final result = await adapter.setEnabled(true);

    expect(result.enabled, isFalse);
    expect(result.message, contains('another executable'));
    expect(store.shortcut?.target, otherExecutable);
  });

  test('enabling repairs stale shortcut metadata', () async {
    final executable = Platform.resolvedExecutable;
    final store = _FakeWindowsLaunchAtLoginStore(
      shortcut: WindowsStartupShortcut(
        target: executable,
        workingDirectory: r'C:\Wrong',
        arguments: '--unexpected',
      ),
    );
    final adapter = WindowsExeLaunchAtLoginAdapter(
      executable: executable,
      store: store,
    );

    expect((await adapter.query()).enabled, isFalse);

    final result = await adapter.setEnabled(true);

    expect(result.enabled, isTrue);
    expect(store.shortcut?.workingDirectory, path.windows.dirname(executable));
    expect(store.shortcut?.arguments, isEmpty);
  });

  test('enabling replaces a missing OneXray shortcut target', () async {
    final executable = Platform.resolvedExecutable;
    final store = _FakeWindowsLaunchAtLoginStore(
      shortcut: _shortcut(r'C:\Removed\OneXray.exe'),
    );
    final adapter = WindowsExeLaunchAtLoginAdapter(
      executable: executable,
      store: store,
    );

    final result = await adapter.setEnabled(true);

    expect(result.enabled, isTrue);
    expect(store.shortcut?.target, executable);
  });

  for (final (action, enabled) in [
    ('query', null),
    ('enabling', true),
    ('disabling', false),
  ]) {
    test('$action preserves an unreadable startup shortcut', () async {
      final executable = Platform.resolvedExecutable;
      final shortcut = _shortcut(executable);
      final store = _FakeWindowsLaunchAtLoginStore(
        shortcut: shortcut,
        shortcutUnreadable: true,
      );
      final adapter = WindowsExeLaunchAtLoginAdapter(
        executable: executable,
        store: store,
      );

      final result = enabled == null
          ? await adapter.query()
          : await adapter.setEnabled(enabled);

      expect(result.state.name, 'error');
      expect(
        result.message,
        'The existing startup shortcut cannot be read: '
        'FormatException: invalid shortcut',
      );
      expect(store.shortcut, same(shortcut));
      expect(store.shortcutUnreadable, isTrue);
    });
  }
}

String _createOtherOneXrayExecutable() {
  final directory =
      (Directory('../references/windows-exe-tests').absolute
            ..createSync(recursive: true))
          .createTempSync('onexray-startup-test-');
  addTearDown(() => directory.deleteSync(recursive: true));
  final executable = File(path.join(directory.path, 'OneXray.exe'));
  executable.writeAsStringSync('test');
  return executable.path;
}

WindowsStartupShortcut _shortcut(String target) {
  return WindowsStartupShortcut(
    target: target,
    workingDirectory: path.windows.dirname(target),
    arguments: '',
  );
}

final class _FakeWindowsLaunchAtLoginStore
    implements WindowsLaunchAtLoginStore {
  WindowsStartupShortcut? shortcut;
  bool shortcutUnreadable;

  _FakeWindowsLaunchAtLoginStore({
    this.shortcut,
    this.shortcutUnreadable = false,
  });

  @override
  bool shortcutExists() => shortcut != null || shortcutUnreadable;

  @override
  WindowsStartupShortcut? readShortcut() {
    if (shortcutUnreadable) {
      throw const FormatException('invalid shortcut');
    }
    return shortcut;
  }

  @override
  void writeShortcut({
    required String target,
    required String workingDirectory,
    required String arguments,
  }) {
    shortcutUnreadable = false;
    shortcut = WindowsStartupShortcut(
      target: target,
      workingDirectory: workingDirectory,
      arguments: arguments,
    );
  }

  @override
  void deleteShortcut() {
    shortcutUnreadable = false;
    shortcut = null;
  }
}
