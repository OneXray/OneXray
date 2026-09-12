import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/windows/core_process.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late String name;
  late WindowsCoreProcess core;

  setUp(() async {
    final root = Directory('../references/windows-core-process-tests').absolute;
    await root.create(recursive: true);
    directory = await root.createTemp('native-');
    addTearDown(() => directory.delete(recursive: true));
    // Native operations use a unique fixture name, never real OneXrayCore.
    name = 'OneXrayFixture-$pid-${DateTime.now().microsecondsSinceEpoch}.exe';
    core = WindowsCoreProcess.forTesting(processName: name);
  });

  Future<Process> launch(String folder, String imageName) async {
    final executable = File(p.join(directory.path, folder, imageName));
    await executable.parent.create(recursive: true);
    await File(
      p.join(Platform.environment['SystemRoot']!, 'System32', 'cmd.exe'),
    ).copy(executable.path);
    // The renamed Windows command interpreter waits on stdin. It starts no
    // children, uses no network and needs neither a compiler nor elevation.
    final process = await Process.start(
      await executable.resolveSymbolicLinks(),
      ['/d', '/q', '/c', 'set /p value=$name'],
    );
    process.stdout.drain<void>();
    process.stderr.drain<void>();
    addTearDown(() async {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
      await process.stdin.close();
    });
    return process;
  }

  test(
    'Win32 stop waits for all matches and leaves a similar name alive',
    () async {
      final first = await launch('one', name);
      final second = await launch('two', name);
      final otherName = '${p.basenameWithoutExtension(name)}-extra.exe';
      final other = await launch('neighbor', otherName);
      final watches = [core.watchExit(first.pid), core.watchExit(second.pid)];
      addTearDown(() async {
        for (final watch in watches) {
          watch.cancel();
          await watch.exited;
        }
      });
      await core.stopAll().timeout(const Duration(seconds: 8));
      expect(await Future.wait(watches.map((watch) => watch.exited)), [
        true,
        true,
      ]);
      expect(await core.findPids(), isEmpty);
      expect(
        await WindowsCoreProcess.forTesting(processName: otherName).findPids(),
        {other.pid},
      );
      // Repeating stop with no matches neither fails nor touches the neighbor.
      await core.stopAll();
      expect(
        await WindowsCoreProcess.forTesting(processName: otherName).findPids(),
        {other.pid},
      );
    },
    skip: !Platform.isWindows,
  );

  test(
    'Win32 exit waits can be cancelled and observe a later natural exit',
    () async {
      final process = await launch('one', name);
      final cancelled = core.watchExit(process.pid);
      cancelled.cancel();
      expect(
        await cancelled.exited.timeout(const Duration(seconds: 5)),
        isFalse,
      );
      expect(await core.findPids(), {process.pid});
      final exited = core.watchExit(process.pid);
      addTearDown(() async {
        exited.cancel();
        await exited.exited;
      });
      await process.stdin.close();
      expect(await exited.exited.timeout(const Duration(seconds: 5)), isTrue);
      expect(await core.findPids(), isEmpty);
      expect(await core.watchExit(process.pid).exited, isTrue);
    },
    skip: !Platform.isWindows,
  );

  test(
    'Win32 treats an already exited named process as exited under contention',
    () async {
      final process = await launch('one', name);
      await process.stdin.close();
      await process.exitCode;
      final watches = [
        for (var i = 0; i < 32; i++) core.watchExit(process.pid),
      ];
      addTearDown(() {
        for (final watch in watches) {
          watch.cancel();
        }
      });
      expect(
        await Future.wait(watches.map((watch) => watch.exited))
            .timeout(const Duration(seconds: 10)),
        everyElement(isTrue),
      );
    },
    skip: !Platform.isWindows,
  );

  test(
    'Win32 does not attach an exit wait to a different process name',
    () async {
      final otherName = '${p.basenameWithoutExtension(name)}-extra.exe';
      final other = await launch('neighbor', otherName);
      expect(
        await core
            .watchExit(other.pid)
            .exited
            .timeout(const Duration(seconds: 5)),
        isTrue,
      );
      expect(
        await WindowsCoreProcess.forTesting(processName: otherName).findPids(),
        {other.pid},
      );
    },
    skip: !Platform.isWindows,
  );

  test(
    'Win32 matches exact names across directories, not prefixes or argv',
    () async {
      final first = await launch('安装 one', name);
      final second = await launch('安装 two', name.toUpperCase());
      await launch('neighbor', '${p.basenameWithoutExtension(name)}-extra.exe');
      expect(await core.findPids(), {first.pid, second.pid});
    },
    skip: !Platform.isWindows,
  );
}
