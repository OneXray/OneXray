import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/desktop_core_process.dart';
import 'package:onexray/core/ffi/linux_ffi_api.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'reopens a verified managed PID and stops only that recorded process',
    () async {
      final fixture = await _Fixture.create();
      await fixture.writeRecord();
      await fixture.writeProcess(42);
      await fixture.writeProcess(43);
      final api = fixture.api((pid, signal) {
        fixture.signals.add((pid: pid, signal: signal));
        Directory(p.join(fixture.proc.path, '$pid'))
            .deleteSync(recursive: true);
        return true;
      });

      expect(api.needsVpnStatusPolling, isFalse);
      expect(
        await api.queryCoreRunning(),
        isTrue,
      ); // No in-memory Process exists.
      expect(api.needsVpnStatusPolling, isTrue);
      expect(await api.cleanupStaleCore(), isTrue);
      expect(fixture.signals, isEmpty);
      expect(await api.stopCore(), isTrue);
      expect(api.needsVpnStatusPolling, isFalse);
      expect(fixture.signals, [(pid: 42, signal: ProcessSignal.sigterm)]);
      expect(await Directory(p.join(fixture.proc.path, '43')).exists(), isTrue);
      expect(await fixture.store.read(), isNull);
      expect(await api.queryCoreRunning(), isFalse);
    },
  );

  test('stops polling a restored process after its verified exit', () async {
    final fixture = await _Fixture.create();
    await fixture.writeRecord();
    await fixture.writeProcess(42);
    final api = fixture.api((_, _) => false);
    expect(await api.queryCoreRunning(), isTrue);
    expect(api.needsVpnStatusPolling, isTrue);
    await Directory(p.join(fixture.proc.path, '42')).delete(recursive: true);
    expect(await api.queryCoreRunning(), isFalse);
    expect(api.needsVpnStatusPolling, isFalse);
  });

  test('rejects PID reuse, another executable, config changes and missing runtime argv', () async {
    for (final mismatch in ['ticks', 'exe', 'config', 'runtime']) {
      final fixture = await _Fixture.create();
      await fixture.writeRecord();
      final otherExecutable = File(
        p.join(fixture.directory.path, 'other', 'OneXrayCore'),
      );
      await otherExecutable.parent.create();
      await otherExecutable.writeAsString('not executed');
      await fixture.writeProcess(
        42,
        ticks: mismatch == 'ticks' ? 124 : 123,
        executable: mismatch == 'exe' ? otherExecutable.path : null,
        configPath: mismatch == 'config'
            ? '${fixture.config.path}.different'
            : null,
        includeRuntime: mismatch != 'runtime',
      );
      final api = fixture.api((pid, signal) {
        fixture.signals.add((pid: pid, signal: signal));
        return true;
      });
      expect(await api.queryCoreRunning(), isNull, reason: mismatch);
      expect(api.needsVpnStatusPolling, isFalse, reason: mismatch);
      expect(await api.cleanupStaleCore(), isFalse, reason: mismatch);
      expect(await api.stopCore(), isFalse, reason: mismatch);
      expect(fixture.signals, isEmpty, reason: mismatch);
      expect(await fixture.recordFile.exists(), isTrue, reason: mismatch);
    }
  });

  test('legacy PID-only and unreadable records stay intact instead of claiming cleanup', () async {
    final fixture = await _Fixture.create();
    await fixture.writeProcess(42);
    final api = fixture.api((pid, signal) {
      fixture.signals.add((pid: pid, signal: signal));
      return true;
    });
    await fixture.store.write(const DesktopCoreProcessRecord(pid: 42));
    expect(await api.queryCoreRunning(), isNull);
    expect(await api.stopCore(), isFalse);
    expect(await fixture.recordFile.readAsString(), contains('42'));
    await fixture.recordFile.writeAsString('invalid JSON');
    expect(await api.queryCoreRunning(), isNull);
    expect(await api.cleanupStaleCore(), isFalse);
    expect(await api.stopCore(), isFalse);
    expect(await fixture.recordFile.readAsString(), 'invalid JSON');
    expect(fixture.signals, isEmpty);
  });

  test(
    'PID reuse after SIGTERM prevents escalation and keeps the evidence',
    () async {
      final fixture = await _Fixture.create();
      await fixture.writeRecord();
      await fixture.writeProcess(42);
      final api = fixture.api((pid, signal) {
        fixture.signals.add((pid: pid, signal: signal));
        File(p.join(fixture.proc.path, '$pid', 'stat')).writeAsStringSync(
          '$pid (OneXrayCore) S ${List.filled(18, '0').join(' ')} 124',
        );
        return true;
      });
      expect(await api.stopCore(), isFalse);
      expect(fixture.signals, [(pid: 42, signal: ProcessSignal.sigterm)]);
      expect(await fixture.recordFile.exists(), isTrue);
    },
  );

  test('absent recorded PID is cleared, but a config outside App files is not owned', () async {
    final fixture = await _Fixture.create();
    await fixture.writeRecord();
    final api = fixture.api((pid, signal) {
      fixture.signals.add((pid: pid, signal: signal));
      return true;
    });
    expect(await api.queryCoreRunning(), isFalse);
    expect(await api.stopCore(), isTrue);
    expect(await fixture.store.read(), isNull);
    final outside = File(p.join(fixture.directory.path, 'outside.json'));
    await outside.writeAsString('{}');
    await fixture.store.write(
      DesktopCoreProcessRecord(
        pid: 42,
        configPath: outside.path,
        startTicks: 123,
      ),
    );
    await fixture.writeProcess(
      42,
      configPath: outside.path,
      includeRuntime: false,
    );
    expect(await api.queryCoreRunning(), isNull);
    expect(await api.stopCore(), isFalse);
    expect(await fixture.recordFile.exists(), isTrue);
    expect(fixture.signals, isEmpty);
  });
}

class _Fixture {
  final Directory directory;
  final Directory proc;
  final File executable;
  final File config;
  final File runtime;
  final DesktopCoreProcessStore store;
  final signals = <({int pid, ProcessSignal signal})>[];

  _Fixture(
    this.directory,
    this.proc,
    this.executable,
    this.config,
    this.runtime,
  ) : store = DesktopCoreProcessStore(directory: directory.path);

  File get recordFile =>
      File(p.join(directory.path, 'run', 'core-process.json'));

  static Future<_Fixture> create() async {
    final fixtures = await Directory(
      '../references/onexray-refactor-validation/test-fixtures',
    ).absolute.create(recursive: true);
    final directory = await fixtures.createTemp('onexray-linux-process-');
    addTearDown(() => directory.delete(recursive: true));
    final proc = await Directory(p.join(directory.path, 'proc')).create();
    final executable = File(p.join(directory.path, 'OneXrayCore'));
    await executable.writeAsString('not executed');
    final plan = await Directory(p.join(directory.path, 'run', 'plans', 'plan'))
        .create(recursive: true);
    final config = File(p.join(plan.path, 'xray.json'));
    final runtime = File(p.join(plan.path, 'runtime-config.json'));
    await config.writeAsString('{}');
    await runtime.writeAsString('{}');
    return _Fixture(directory, proc, executable, config, runtime);
  }

  LinuxFfiApi api(bool Function(int, ProcessSignal) signal) {
    final api = LinuxFfiApi.forTesting(
      filesDirectory: directory.path,
      executablePath: executable.path,
      procDirectory: proc.path,
      signalProcess: signal,
    );
    addTearDown(api.stopSharedIsolate);
    return api;
  }

  Future<void> writeRecord() => store.write(
    DesktopCoreProcessRecord(
      pid: 42,
      configPath: config.path,
      runtimePath: runtime.path,
      startTicks: 123,
    ),
  );

  Future<void> writeProcess(
    int pid, {
    int ticks = 123,
    String? executable,
    String? configPath,
    bool includeRuntime = true,
  }) async {
    final folder = await Directory(p.join(proc.path, '$pid')).create();
    await Link(p.join(folder.path, 'exe'))
        .create(executable ?? this.executable.path);
    await File(p.join(folder.path, 'stat')).writeAsString(
      '$pid (OneXrayCore) S ${List.filled(18, '0').join(' ')} $ticks',
    );
    final args = [
      this.executable.path,
      'run',
      '-config',
      configPath ?? config.path,
      if (includeRuntime) ...['-runtime', runtime.path],
      '',
    ];
    await File(p.join(folder.path, 'cmdline'))
        .writeAsBytes(utf8.encode(args.join('\x00')));
  }
}
