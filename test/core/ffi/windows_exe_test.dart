import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/desktop_core_process.dart';
import 'package:onexray/core/ffi/windows/core_process.dart';
import 'package:onexray/core/ffi/windows/exe_ffi_api.dart';
import 'package:onexray/core/ffi/windows/ffi_api.dart';
import 'package:onexray/core/ffi/windows/mode.dart';
import 'package:onexray/core/ffi/windows/msix_ffi_api.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/model/tun_json.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late _Process process;
  late List<VpnStatus> events;

  WindowsExeFfiApi create() => WindowsExeFfiApi(
    filesDirectory: directory.path,
    executable: p.join(directory.path, 'OneXrayCore.exe'),
    process: process,
    readRequest: () async => StartVpnRequest(
      TunJson.fromJson({
        'tunDnsIPv4': '8.8.8.8',
        'autoOutboundsInterface': 'Ethernet 2',
      }),
      '18187',
      '18186',
      jsonEncode(
        LibXrayInvokeRequest(
          method: LibXrayMethod.runXray,
          payload: RunXrayRequest('{"inbounds":[]}').toJson(),
        ).toJson(),
      ),
    ),
    notify: (status) async => events.add(status),
  );

  setUp(() async {
    final root = Directory('../references/windows-exe-tests').absolute;
    await root.create(recursive: true);
    directory = await root.createTemp('ffi-');
    process = _Process();
    events = [];
    addTearDown(() => directory.delete(recursive: true));
  });

  test('the compile-time mode chooses one Windows implementation', () {
    const configured = String.fromEnvironment(
      'ONEXRAY_WINDOWS_MODE',
      defaultValue: 'exe',
    );
    expect(windowsBuildMode.name, configured);
    expect(
      WindowsFfiApi(),
      configured == 'msix' ? isA<WindowsMsixFfiApi>() : isA<WindowsExeFfiApi>(),
    );
  });

  test(
    'MSIX environment failures never fall back to an unpackaged directory',
    () async {
      final api = WindowsMsixFfiApi(
        native: WindowsNativeApi.forTest((_) async {
          throw StateError('Package identity is unavailable');
        }),
      );
      await expectLater(api.getTunFilesDir(), throwsStateError);
    },
  );

  test('empty EXE status/stop need no VCore or package identity', () async {
    final api = create();
    expect(await api.getTunFilesDir(), directory.path);
    expect((await api.readVpnStatus()).status, VpnStatus.disconnected);
    expect((await api.stopVpn()).status, VpnStatus.disconnected);
    expect(process.stops, 0);
  });

  test(
    'EXE starts with current CLI arguments and replaces old inputs',
    () async {
      final old = File(
        p.join(directory.path, 'run', 'core-inputs', 'old.json'),
      );
      await old.parent.create(recursive: true);
      await old.writeAsString('{}');
      final api = create();
      final starting = api.startVpn();
      await process.launched.future;
      expect((await api.readVpnStatus()).status, VpnStatus.connecting);
      expect((await starting).status, VpnStatus.connected);
      expect(await old.exists(), false);
      expect(process.arguments!.take(5), [
        'run',
        '-dns',
        '8.8.8.8:53',
        '-interface',
        'Ethernet 2',
      ]);
      expect(process.arguments![5], '-config');
      expect(
        await File(process.arguments!.last).readAsString(),
        '{"inbounds":[]}',
      );
      final record = await DesktopCoreProcessStore(directory: directory.path)
          .read();
      expect(record?.pid, 42);
      expect(record?.startTicks, 100);
      expect(record?.configPath, process.arguments!.last);
      // A second App instance can read/stop the same recorded process.
      final reopened = create();
      expect((await reopened.readVpnStatus()).status, VpnStatus.connected);
      expect((await reopened.stopVpn()).status, VpnStatus.disconnected);
      expect(
        await DesktopCoreProcessStore(directory: directory.path).read(),
        isNull,
      );
    },
  );

  test(
    'UAC cancellation fails without leaving a running/connecting state',
    () async {
      process.failStart = true;
      final api = create();
      final result = await api.startVpn();
      expect(result.state, NativeVpnCommandState.failed);
      expect(result.message, contains('cancelled'));
      expect((await api.readVpnStatus()).status, VpnStatus.disconnected);
      expect(events.last, VpnStatus.disconnected);
    },
  );

  test('stop failure preserves the running record for retry', () async {
    final api = create();
    await api.startVpn();
    process.failStop = true;
    expect((await api.stopVpn()).state, NativeVpnCommandState.failed);
    expect((await api.readVpnStatus()).status, VpnStatus.connected);
    expect(
      await DesktopCoreProcessStore(directory: directory.path).read(),
      isNotNull,
    );
    process.failStop = false;
    expect((await api.stopVpn()).status, VpnStatus.disconnected);
  });

  test('process exit clears only the exited record', () async {
    final api = create();
    await api.startVpn();
    process.running = false;
    expect((await api.readVpnStatus()).status, VpnStatus.disconnected);
    expect(
      await DesktopCoreProcessStore(directory: directory.path).read(),
      isNull,
    );
  });

  test('Windows arguments preserve spaces, quotes and trailing slashes', () {
    expect(quoteWindowsArgument('Ethernet 2'), '"Ethernet 2"');
    expect(quoteWindowsArgument(''), '""');
    expect(quoteWindowsArgument(r'a"b'), r'"a\"b"');
    expect(quoteWindowsArgument('C:\\目录\\'), '"C:\\目录\\\\"');
    expect(quoteWindowsArgument(r'a\"b'), r'"a\\\"b"');
  });
}

class _Process extends WindowsCoreProcess {
  bool running = false;
  bool failStart = false;
  bool failStop = false;
  int stops = 0;
  List<String>? arguments;
  final launched = Completer<void>();

  @override
  Future<DesktopCoreProcessRecord> start(
    String executable,
    List<String> arguments,
    String configPath,
  ) async {
    if (failStart) throw StateError('UAC cancelled');
    this.arguments = arguments;
    running = true;
    launched.complete();
    return DesktopCoreProcessRecord(
      pid: 42,
      startTicks: 100,
      configPath: configPath,
    );
  }

  @override
  Future<bool> isRunning(
    DesktopCoreProcessRecord record,
    String executable,
  ) async => running;

  @override
  Future<void> stop(DesktopCoreProcessRecord record, String executable) async {
    if (failStop) throw StateError('Stop failed');
    stops++;
    running = false;
  }
}
