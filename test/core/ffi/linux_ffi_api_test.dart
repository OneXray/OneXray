import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/desktop_core_exit.dart';
import 'package:onexray/core/ffi/linux_ffi_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'finds Core by exact name without executable links or PID records',
    () async {
      final fixture = await _Fixture.create();
      await fixture.writeProcess(42);
      final api = fixture.api((_, _) => false);

      expect(await api.queryCoreRunning(), isTrue);
      expect((await api.readVpnStatus()).status, VpnStatus.connected);
    },
  );

  test('stops all exact-name Core processes without touching xray', () async {
    final fixture = await _Fixture.create();
    await fixture.writeProcess(42);
    await fixture.writeProcess(43);
    await fixture.writeProcess(44, name: 'xray');
    await fixture.writeProcess(45, name: 'OneXray');
    await fixture.writeProcess(46, name: 'OneXrayCoreHelper');
    final api = fixture.api((pid, _) {
      fixture.exitProcess(pid);
      return true;
    });

    expect(await api.stopCore(), isTrue);
    expect((await api.readVpnStatus()).status, VpnStatus.disconnected);
    expect(
      fixture.signals.map((value) => value.pid),
      unorderedEquals([42, 43]),
    );
    for (final pid in [44, 45, 46]) {
      expect(
        await Directory(p.join(fixture.proc.path, '$pid')).exists(),
        isTrue,
      );
    }
  });

  test('zombies and exited processes are not a connected VPN', () async {
    final fixture = await _Fixture.create();
    await fixture.writeProcess(42, state: 'Z');
    await fixture.writeProcess(43, state: 'X');
    await fixture.writeProcess(44, name: 'xray');
    final api = fixture.api((_, _) => false);

    expect((await api.readVpnStatus()).status, VpnStatus.disconnected);
    expect(await api.stopCore(), isTrue);
    expect(fixture.signals, isEmpty);
  });

  test(
    'unreadable legacy PID records do not block discovery or stop',
    () async {
      final fixture = await _Fixture.create();
      final oldRecord = File(
        p.join(fixture.directory.path, 'run', 'core-process.json'),
      );
      await oldRecord.parent.create();
      await oldRecord.writeAsString('invalid JSON');
      await fixture.writeProcess(42);
      final api = fixture.api((pid, _) {
        fixture.exitProcess(pid);
        return true;
      });

      expect(await api.cleanupStaleCore(), isTrue);
      expect(fixture.signals, isEmpty);
      expect((await api.readVpnStatus()).status, VpnStatus.connected);
      expect(await api.stopCore(), isTrue);
      expect((await api.readVpnStatus()).status, VpnStatus.disconnected);
    },
  );

  test('a discovered Core publishes its exit without a status poll', () async {
    final fixture = await _Fixture.create();
    await fixture.writeProcess(42);
    final api = fixture.api((_, _) => false);
    await api.observeVpnStatus();
    expect(fixture.watchedPids, [42]);

    final nextStatus = fixture.nextStatus();
    fixture.exitProcess(42);
    expect(await nextStatus, VpnStatus.disconnected);
    expect((await api.readVpnStatus()).status, VpnStatus.disconnected);
  });

  test('only the last named Core exit disconnects the VPN', () async {
    final fixture = await _Fixture.create();
    await fixture.writeProcess(42);
    await fixture.writeProcess(43);
    final api = fixture.api((_, _) => false);
    await api.observeVpnStatus();

    var nextStatus = fixture.nextStatus();
    fixture.exitProcess(42);
    expect(await nextStatus, VpnStatus.connected);
    nextStatus = fixture.nextStatus();
    fixture.exitProcess(43);
    expect(await nextStatus, VpnStatus.disconnected);
  });

  test('disposing exit observation suppresses late notifications', () async {
    final fixture = await _Fixture.create();
    await fixture.writeProcess(42);
    final api = fixture.api((_, _) => false);
    await api.observeVpnStatus();
    api.disposeVpnStatus();
    fixture.exitProcess(42);
    await Future<void>.delayed(Duration.zero);

    expect(fixture.events, isEmpty);
  });

  test('a failed signal does not claim that the VPN stopped', () async {
    final fixture = await _Fixture.create();
    await fixture.writeProcess(42);
    final api = fixture.api((_, _) => false);

    expect((await api.stopVpn()).state, NativeVpnCommandState.failed);
    expect((await api.readVpnStatus()).status, VpnStatus.connected);
    expect(fixture.events, [VpnStatus.disconnecting]);
  });

  test(
    'an unresponsive named Core is killed after the graceful stop deadline',
    () async {
      final fixture = await _Fixture.create();
      await fixture.writeProcess(42);
      final api = fixture.api((pid, signal) {
        if (signal == ProcessSignal.sigkill) fixture.exitProcess(pid);
        return true;
      });

      expect((await api.stopVpn()).status, VpnStatus.disconnected);
      expect(fixture.signals, [
        (pid: 42, signal: ProcessSignal.sigterm),
        (pid: 42, signal: ProcessSignal.sigkill),
      ]);
      expect(fixture.events, [VpnStatus.disconnecting, VpnStatus.disconnected]);
    },
  );

  test('a PID now named xray is no longer a Core target', () async {
    final fixture = await _Fixture.create();
    await fixture.writeProcess(42);
    final api = fixture.api((pid, _) {
      File(p.join(fixture.proc.path, '$pid', 'stat'))
          .writeAsStringSync('$pid (xray) S');
      return true;
    });

    expect(await api.stopCore(), isTrue);
    expect(fixture.signals, [(pid: 42, signal: ProcessSignal.sigterm)]);
    expect(await Directory(p.join(fixture.proc.path, '42')).exists(), isTrue);
  });

  test('process discovery failure is not treated as disconnected', () async {
    final fixture = await _Fixture.create();
    final api = fixture.api((_, _) => false);
    await fixture.proc.delete(recursive: true);

    expect(await api.queryCoreRunning(), isNull);
    expect((await api.readVpnStatus()).state, NativeVpnCommandState.failed);
    expect(await api.cleanupStaleCore(), isFalse);
    expect(await api.stopCore(), isFalse);
    expect(fixture.signals, isEmpty);
  });
}

class _Fixture {
  final Directory directory;
  final Directory proc;
  final signals = <({int pid, ProcessSignal signal})>[];
  final watchedPids = <int>[];
  final events = <VpnStatus>[];
  final _statuses = StreamController<VpnStatus>.broadcast();
  final _exits = <int, Completer<bool>>{};

  _Fixture(this.directory, this.proc);

  static Future<_Fixture> create() async {
    final fixtures = await Directory(
      '../references/onexray-refactor-validation/test-fixtures',
    ).absolute.create(recursive: true);
    final directory = await fixtures.createTemp('onexray-linux-process-');
    final fixture = _Fixture(
      directory,
      await Directory(p.join(directory.path, 'proc')).create(),
    );
    addTearDown(() => directory.delete(recursive: true));
    addTearDown(fixture._statuses.close);
    return fixture;
  }

  LinuxFfiApi api(bool Function(int, ProcessSignal) signal) {
    final api = LinuxFfiApi.forTesting(
      filesDirectory: directory.path,
      executablePath: p.join(directory.path, 'OneXrayCore'),
      procDirectory: proc.path,
      signalProcess: (pid, value) {
        signals.add((pid: pid, signal: value));
        return signal(pid, value);
      },
      watchExit: (pid) {
        watchedPids.add(pid);
        final exited = _exits.putIfAbsent(pid, () => Completer<bool>());
        return DesktopCoreExitWatch(exited.future, () {
          if (!exited.isCompleted) exited.complete(false);
        });
      },
      notify: (status) async {
        events.add(status);
        _statuses.add(status);
      },
      notifyError: (error) => fail('Unexpected watch error: $error'),
    );
    addTearDown(api.disposeVpnStatus);
    addTearDown(api.stopSharedIsolate);
    return api;
  }

  Future<void> writeProcess(
    int pid, {
    String name = 'OneXrayCore',
    String state = 'S',
  }) async {
    final folder = await Directory(p.join(proc.path, '$pid')).create();
    // Deliberately omit exe, cmdline, UIDs and start ticks.
    await File(p.join(folder.path, 'stat'))
        .writeAsString('$pid ($name) $state');
  }

  void exitProcess(int pid) {
    Directory(p.join(proc.path, '$pid')).deleteSync(recursive: true);
    final exited = _exits[pid];
    if (exited != null && !exited.isCompleted) exited.complete(true);
  }

  Future<VpnStatus> nextStatus() =>
      _statuses.stream.first.timeout(const Duration(seconds: 2));
}
