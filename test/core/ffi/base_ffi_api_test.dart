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
        configPath: '/plan/xray.json',
        runtimePath: '/plan/runtime-config.json',
      ),
      [
        'run',
        '-dns',
        '8.8.8.8:53',
        '-interface',
        'eth0',
        '-config',
        '/plan/xray.json',
        '-runtime',
        '/plan/runtime-config.json',
      ],
    );
    expect(
      () => desktopCoreRunArguments(
        dns: '8.8.8.8',
        interfaceName: 'eth0',
        configPath: '/plan/xray.json',
        runtimePath: '',
      ),
      throwsFormatException,
    );
  });

  test('publishes immutable plan inputs without wrapping or losing runtime metadata', () async {
    final directory = await Directory.systemTemp.createTemp(
      'onexray-desktop-inputs-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final api = _TestFfiApi(stopResult: true, directory: directory.path);
    addTearDown(api.stopSharedIsolate);
    const text = '{"outbounds":[{"protocol":"freedom"}]}';
    final runtime = ManagedRuntimeRequest(
      statePath: p.join(directory.path, 'run', 'runtime.json'),
      planId: '0123456789abcdef0123456789abcdef',
      inboundTag: 'tunIn',
    );
    final request = _request(text, runtime);
    final inputs = (await api.materializeRunXrayConfig(request))!;
    expect(
      p.dirname(inputs.configPath),
      p.join(directory.path, 'run', 'plans', runtime.planId),
    );
    expect(p.dirname(inputs.runtimePath!), p.dirname(inputs.configPath));
    expect(await File(inputs.configPath).readAsString(), text);
    expect(
      jsonDecode(await File(inputs.runtimePath!).readAsString()),
      runtime.toJson(),
    );
    expect(await api.materializeRunXrayConfig(request), inputs);
    await expectLater(
      api.materializeRunXrayConfig(_request('{}', runtime)),
      throwsFormatException,
    );
    expect(await File(inputs.configPath).readAsString(), text);
    final changedRuntime = ManagedRuntimeRequest(
      statePath: runtime.statePath,
      planId: runtime.planId,
      inboundTag: 'changed',
    );
    await expectLater(
      api.materializeRunXrayConfig(_request(text, changedRuntime)),
      throwsFormatException,
    );
    expect(
      jsonDecode(await File(inputs.runtimePath!).readAsString()),
      runtime.toJson(),
    );
    final arguments = desktopCoreRunArguments(
      dns: '8.8.8.8',
      interfaceName: 'eth0',
      configPath: inputs.configPath,
      runtimePath: inputs.runtimePath,
    );
    expect(arguments, isNot(contains(runtime.statePath)));
  });

  test(
    'legacy inputs stay immutable and plan IDs cannot escape their directory',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'onexray-desktop-legacy-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final api = _TestFfiApi(stopResult: true, directory: directory.path);
      addTearDown(api.stopSharedIsolate);
      final first = (await api.materializeRunXrayConfig(_request('{"a":1}')))!;
      final second = (await api.materializeRunXrayConfig(_request('{"a":2}')))!;
      expect(first.configPath, isNot(second.configPath));
      expect(first.runtimePath, isNull);
      expect(await File(first.configPath).readAsString(), '{"a":1}');
      await expectLater(
        api.materializeRunXrayConfig(
          _request(
            '{}',
            const ManagedRuntimeRequest(
              statePath: '/state.json',
              planId: '../outside',
            ),
          ),
        ),
        throwsFormatException,
      );
      expect(await api.materializeRunXrayConfig(_request('')), isNull);
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
