import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:path/path.dart' as p;

void main() {
  test('builds protected desktop Core arguments', () {
    expect(
      desktopCoreRunArguments(
        dns: '8.8.8.8',
        interfaceName: 'Ethernet',
        configPath: r'C:\run\xray.json',
      ),
      <String>[
        'run',
        '-dns',
        '8.8.8.8:53',
        '-interface',
        'Ethernet',
        '-config',
        r'C:\run\xray.json',
      ],
    );
    expect(
      () => desktopCoreRunArguments(
        dns: '',
        interfaceName: 'Ethernet',
        configPath: 'xray.json',
      ),
      throwsFormatException,
    );
    expect(
      desktopCoreRunArguments(
        dns: '8.8.8.8',
        interfaceName: 'eth0',
        configPath: '/runtime-input/xray.json',
        runtimePath: '/runtime-input/runtime-config.json',
      ),
      [
        'run',
        '-dns',
        '8.8.8.8:53',
        '-interface',
        'eth0',
        '-config',
        '/runtime-input/xray.json',
        '-runtime',
        '/runtime-input/runtime-config.json',
      ],
    );
    expect(
      () => desktopCoreRunArguments(
        dns: '8.8.8.8',
        interfaceName: 'eth0',
        configPath: '/runtime-input/xray.json',
        runtimePath: '',
      ),
      throwsFormatException,
    );
  });

  test(
    'replaces old inputs with one unique immutable runtime directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'onexray-desktop-inputs-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final api = _TestFfiApi(stopResult: true, directory: directory.path);
      addTearDown(api.stopSharedIsolate);
      final stale = File(
        p.join(directory.path, 'run', 'core-inputs', 'stale', 'xray.json'),
      );
      await stale.parent.create(recursive: true);
      await stale.writeAsString('stale');
      final sibling = File(p.join(directory.path, 'run', 'keep'));
      await sibling.writeAsString('keep');
      const text = '{"outbounds":[{"protocol":"freedom"}]}';
      final runtime = ManagedRuntimeRequest(
        statePath: p.join(directory.path, 'run', 'runtime.json'),
        inboundTag: 'tunIn',
      );
      final request = _request(text, runtime);
      final first = (await api.materializeRunXrayConfig(request))!;
      expect(
        p.dirname(p.dirname(first.configPath)),
        p.join(directory.path, 'run', 'core-inputs'),
      );
      expect(p.dirname(first.runtimePath!), p.dirname(first.configPath));
      expect(await stale.exists(), isFalse);
      expect(await sibling.readAsString(), 'keep');
      expect(await File(first.configPath).readAsString(), text);
      expect(
        jsonDecode(await File(first.runtimePath!).readAsString()),
        runtime.toJson(),
      );
      final second = (await api.materializeRunXrayConfig(request))!;
      expect(second.configPath, isNot(first.configPath));
      expect(await Directory(p.dirname(first.configPath)).exists(), isFalse);
      expect(await File(second.configPath).readAsString(), text);
      expect(
        jsonDecode(await File(second.runtimePath!).readAsString()),
        runtime.toJson(),
      );
      final arguments = desktopCoreRunArguments(
        dns: '8.8.8.8',
        interfaceName: 'eth0',
        configPath: second.configPath,
        runtimePath: second.runtimePath,
      );
      expect(arguments, isNot(contains(runtime.statePath)));
    },
  );

  test(
    'unmanaged inputs are unique and an invalid root is not replaced',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'onexray-desktop-legacy-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final api = _TestFfiApi(stopResult: true, directory: directory.path);
      addTearDown(api.stopSharedIsolate);
      final first = (await api.materializeRunXrayConfig(_request('{"a":1}')))!;
      expect(await File(first.configPath).readAsString(), '{"a":1}');
      final second = (await api.materializeRunXrayConfig(_request('{"a":2}')))!;
      expect(first.configPath, isNot(second.configPath));
      expect(first.runtimePath, isNull);
      expect(await File(first.configPath).exists(), isFalse);
      expect(await File(second.configPath).readAsString(), '{"a":2}');
      expect(second.runtimePath, isNull);
      expect(await api.materializeRunXrayConfig(_request('')), isNull);
      expect(await File(second.configPath).exists(), isFalse);

      final root = Directory(p.join(directory.path, 'run', 'core-inputs'));
      await root.delete(recursive: true);
      await File(root.path).writeAsString('not a directory');
      await expectLater(
        api.materializeRunXrayConfig(_request('{}')),
        throwsFormatException,
      );
    },
  );

  test('reports disconnected only after Core stops successfully', () async {
    final api = _TestFfiApi(stopResult: true);
    addTearDown(api.stopSharedIsolate);

    final result = await api.stopVpn();

    expect(result.state, NativeVpnCommandState.success);
    expect(api.statuses, [VpnStatus.disconnecting, VpnStatus.disconnected]);
  });

  test('restores connected state when Core stop fails', () async {
    final api = _TestFfiApi(stopResult: false);
    addTearDown(api.stopSharedIsolate);

    final result = await api.stopVpn();

    expect(result.state, NativeVpnCommandState.failed);
    expect(api.statuses, [VpnStatus.disconnecting, VpnStatus.connected]);
  });
}

final class _TestFfiApi extends BaseFfiApi {
  final bool stopResult;
  final String? directory;
  final List<VpnStatus> statuses = [];

  _TestFfiApi({required this.stopResult, this.directory});

  @override
  Future<String> getTunFilesDir() async =>
      directory ?? await super.getTunFilesDir();

  @override
  Future<bool> stopCore() async => stopResult;

  @override
  Future<void> updateVpnStatus(VpnStatus status) async {
    statuses.add(status);
  }
}

LibXrayRunConfig _request(String json, [ManagedRuntimeRequest? runtime]) =>
    LibXrayRunConfig(
      LibXrayInvokeRequest(
        method: LibXrayMethod.runXray,
        payload: RunXrayRequest(json, runtime: runtime).toJson(),
      ),
    );
