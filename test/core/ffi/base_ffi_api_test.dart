import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/linux_ffi_api.dart';
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
        errorFile: r'C:\run\xray.json.error',
      ),
      <String>[
        'run',
        '-dns',
        '8.8.8.8:53',
        '-interface',
        'Ethernet',
        '-config',
        r'C:\run\xray.json',
        '-error-file',
        r'C:\run\xray.json.error',
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
      ),
      [
        'run',
        '-dns',
        '8.8.8.8:53',
        '-interface',
        'eth0',
        '-config',
        '/runtime-input/xray.json',
      ],
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
      final request = _request(text);
      final first = (await api.materializeRunXrayConfig(request))!;
      expect(
        p.dirname(p.dirname(first)),
        p.join(directory.path, 'run', 'core-inputs'),
      );
      expect(await stale.exists(), isFalse);
      expect(await sibling.readAsString(), 'keep');
      expect(await File(first).readAsString(), text);
      expect(await desktopCoreErrorFile(first).exists(), isFalse);
      await desktopCoreErrorFile(first).writeAsString('old startup failure');
      expect(
        await readDesktopCoreStartError(first, 'Core exited'),
        'old startup failure',
      );
      final second = (await api.materializeRunXrayConfig(request))!;
      expect(second, isNot(first));
      expect(await Directory(p.dirname(first)).exists(), isFalse);
      expect(await File(second).readAsString(), text);
      expect(await desktopCoreErrorFile(second).exists(), isFalse);
      await desktopCoreErrorFile(second).writeAsString('');
      expect(
        await readDesktopCoreStartError(second, 'Core exited'),
        'Core exited',
      );
      await desktopCoreErrorFile(second).delete();
      expect(
        await readDesktopCoreStartError(second, 'Core exited'),
        'Core exited',
      );
      final arguments = desktopCoreRunArguments(
        dns: '8.8.8.8',
        interfaceName: 'eth0',
        configPath: second,
      );
      expect(arguments, isNot(contains('-runtime')));
    },
  );

  test('inputs are unique and an invalid root is not replaced', () async {
    final directory = await Directory.systemTemp.createTemp(
      'onexray-desktop-legacy-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final api = _TestFfiApi(stopResult: true, directory: directory.path);
    addTearDown(api.stopSharedIsolate);
    final first = (await api.materializeRunXrayConfig(_request('{"a":1}')))!;
    expect(await File(first).readAsString(), '{"a":1}');
    final second = (await api.materializeRunXrayConfig(_request('{"a":2}')))!;
    expect(first, isNot(second));
    expect(await File(first).exists(), isFalse);
    expect(await File(second).readAsString(), '{"a":2}');
    expect(await api.materializeRunXrayConfig(_request('')), isNull);
    expect(await File(second).exists(), isFalse);

    final root = Directory(p.join(directory.path, 'run', 'core-inputs'));
    await root.delete(recursive: true);
    await File(root.path).writeAsString('not a directory');
    await expectLater(
      api.materializeRunXrayConfig(_request('{}')),
      throwsFormatException,
    );
  });

  test('reports disconnected only after Core stops successfully', () async {
    final api = _TestFfiApi(stopResult: true);
    addTearDown(api.stopSharedIsolate);

    final result = await api.stopVpn();

    expect(result.state, NativeVpnCommandState.success);
    expect(api.statuses, [VpnStatus.disconnecting, VpnStatus.disconnected]);
  });

  test('a stop failure never invents a connected state', () async {
    final api = _TestFfiApi(stopResult: false);
    addTearDown(api.stopSharedIsolate);

    final result = await api.stopVpn();

    expect(result.state, NativeVpnCommandState.failed);
    expect(api.statuses, [VpnStatus.disconnecting]);
  });
}

final class _TestFfiApi extends LinuxFfiApi {
  final bool stopResult;
  final String? directory;
  final List<VpnStatus> statuses;

  factory _TestFfiApi({required bool stopResult, String? directory}) =>
      _TestFfiApi._(stopResult, directory, []);

  _TestFfiApi._(this.stopResult, this.directory, this.statuses)
    : super.forTesting(
        filesDirectory: directory ?? '',
        executablePath: '',
        runCommand: (_, _) => throw UnimplementedError(),
        watchExit: (_) => throw UnimplementedError(),
        notify: (status) async => statuses.add(status),
      );

  @override
  Future<String> getTunFilesDir() async =>
      directory ?? await super.getTunFilesDir();

  @override
  Future<bool> stopCore() async => stopResult;
}

LibXrayRunConfig _request(String json) => LibXrayRunConfig(
  LibXrayInvokeRequest(
    method: LibXrayMethod.runXray,
    payload: RunXrayRequest(json).toJson(),
  ),
);
