import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/desktop_startup/linux_adapter.dart';
import 'package:onexray/core/desktop_startup/model.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temporaryDirectory;
  late File executable;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'onexray-linux-autostart-',
    );
    executable = File(
      path.join(temporaryDirectory.path, r'OneXray $100% Test'),
    );
    await executable.writeAsString('');
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('enables, queries, and disables an XDG autostart entry', () async {
    final configHome = path.join(temporaryDirectory.path, 'config');
    final adapter = LinuxLaunchAtLoginAdapter(
      environment: {'XDG_CONFIG_HOME': configHome},
      executable: executable.path,
    );

    expect((await adapter.query()).state, LaunchAtLoginState.disabled);
    expect((await adapter.setEnabled(true)).state, LaunchAtLoginState.enabled);

    final desktopFile = File(
      path.join(configHome, 'autostart', 'net.yuandev.onexray.desktop'),
    );
    final text = await desktopFile.readAsString();
    expect(text, contains('Type=Application'));
    expect(text, contains(r'\$100%% Test"'));
    expect(text, isNot(contains('--autostart')));
    expect(text, contains('TryExec=${executable.path}'));

    expect((await adapter.query()).state, LaunchAtLoginState.enabled);
    expect(
      (await adapter.setEnabled(false)).state,
      LaunchAtLoginState.disabled,
    );
    expect(await desktopFile.exists(), isFalse);
  });

  test('uses HOME when XDG_CONFIG_HOME is unavailable', () async {
    final adapter = LinuxLaunchAtLoginAdapter(
      environment: {'HOME': temporaryDirectory.path},
      executable: executable.path,
    );

    expect((await adapter.setEnabled(true)).state, LaunchAtLoginState.enabled);
    expect(
      await File(
        path.join(
          temporaryDirectory.path,
          '.config',
          'autostart',
          'net.yuandev.onexray.desktop',
        ),
      ).exists(),
      isTrue,
    );
  });

  test('treats a stale owned entry as disabled', () async {
    final configHome = path.join(temporaryDirectory.path, 'config');
    final desktopFile = File(
      path.join(configHome, 'autostart', 'net.yuandev.onexray.desktop'),
    );
    await desktopFile.parent.create(recursive: true);
    await desktopFile.writeAsString(
      '[Desktop Entry]\n'
      'Type=Application\n'
      'Name=OneXray\n'
      'Exec="/old/OneXray"\n'
      'TryExec=/old/OneXray\n'
      'Terminal=false\n',
    );

    final adapter = LinuxLaunchAtLoginAdapter(
      environment: {'XDG_CONFIG_HOME': configHome},
      executable: executable.path,
    );
    final status = await adapter.query();

    expect(status.state, LaunchAtLoginState.disabled);
    expect(status.message, isNotEmpty);
  });

  test('reports unavailable without an autostart home', () async {
    final adapter = LinuxLaunchAtLoginAdapter(
      environment: const {},
      executable: executable.path,
    );

    expect((await adapter.query()).state, LaunchAtLoginState.unavailable);
  });
}
