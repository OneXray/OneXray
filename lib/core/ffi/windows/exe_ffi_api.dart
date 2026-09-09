import 'dart:io';

import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/desktop_core_process.dart';
import 'package:onexray/core/ffi/windows/core_process.dart';
import 'package:onexray/core/ffi/windows/ffi_api.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as p;

class WindowsExeFfiApi extends WindowsFfiApi {
  final WindowsCoreProcess _process;
  final DesktopCoreProcessStore _store;
  final String? _filesDirectory;
  final String _corePath;
  final Future<StartVpnRequest> Function() _readRequest;
  final Future<void> Function(VpnStatus) _notify;
  DesktopCoreProcessRecord? _record;
  VpnStatus? _transition;

  WindowsExeFfiApi({
    WindowsCoreProcess? process,
    String? filesDirectory,
    String? executable,
    Future<StartVpnRequest> Function()? readRequest,
    Future<void> Function(VpnStatus)? notify,
  }) : _process = process ?? WindowsCoreProcess(),
       _filesDirectory = filesDirectory,
       _store = DesktopCoreProcessStore(directory: filesDirectory),
       _corePath =
           executable ??
           p.join(p.dirname(Platform.resolvedExecutable), 'OneXrayCore.exe'),
       _readRequest = readRequest ?? StartVpnRequestReader.readFromStartFile,
       _notify = notify ?? AppFlutterApi().vpnStatusChanged,
       super.base();

  @override
  Future<String> getTunFilesDir() async =>
      _filesDirectory ?? await super.getTunFilesDir();

  @override
  Future<void> ensureRuntime() =>
      checkRuntimeFiles(const ['libXray.dll', 'OneXrayCore.exe', 'wintun.dll']);

  Future<bool> _running() async {
    final record = _record ?? await _store.read();
    if (record == null) return false;
    _record = record;
    if (await _process.isRunning(record, _corePath)) return true;
    await _forget(record);
    return false;
  }

  @override
  Future<NativeVpnCommandResult> readVpnStatus() async {
    try {
      return commandSuccess(
        status:
            _transition ??
            (await _running() ? VpnStatus.connected : VpnStatus.disconnected),
      );
    } catch (error, stackTrace) {
      return _failed('read', error, stackTrace);
    }
  }

  @override
  Future<bool?> cleanupStaleCore() async {
    // Storage upgrade stops a verified running Core via the normal interface.
    final status = await readVpnStatus();
    return status.state == NativeVpnCommandState.success;
  }

  @override
  Future<NativeVpnCommandResult> startVpn({
    String? configYaml,
    WindowsVpnNetworkSettings? networkSettings,
    WindowsVpnPolicy policy = const WindowsVpnPolicy(
      alwaysOn: false,
      allowLocalNetwork: true,
      excludedCidrs: [],
    ),
  }) async {
    if (await _running()) {
      return commandFailed('Stop the current Windows Core before starting');
    }
    _transition = VpnStatus.connecting;
    try {
      await _notify(VpnStatus.connecting);
      final request = await _readRequest();
      final config = await materializeRunXrayConfig(
        readRunXrayRequest(request),
      );
      if (config == null) {
        throw const FormatException('xrayJson is empty');
      }
      final record = await _process.start(
        _corePath,
        desktopCoreRunArguments(
          dns: request.tun?.tunDnsIPv4 ?? '',
          interfaceName: request.tun?.autoOutboundsInterface ?? '',
          configPath: config,
        ),
        config,
      );
      _record = record;
      await _store.write(record);
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!await _running()) {
        throw StateError('Windows Core exited during start');
      }
      await _notify(VpnStatus.connected);
      return commandSuccess(status: VpnStatus.connected);
    } catch (error, stackTrace) {
      try {
        await _stop();
        await _notify(VpnStatus.disconnected);
      } catch (cleanupError) {
        ygLogger('clean up failed Windows Core start: $cleanupError');
      }
      return _failed('start', error, stackTrace);
    } finally {
      _transition = null;
    }
  }

  @override
  Future<NativeVpnCommandResult> stopVpn() async {
    _transition = VpnStatus.disconnecting;
    try {
      await _notify(VpnStatus.disconnecting);
      await _stop();
      await _notify(VpnStatus.disconnected);
      return commandSuccess(status: VpnStatus.disconnected);
    } catch (error, stackTrace) {
      return _failed('stop', error, stackTrace);
    } finally {
      _transition = null;
    }
  }

  Future<void> _stop() async {
    final record = _record ?? await _store.read();
    if (record == null) return;
    _record = record;
    await _process.stop(record, _corePath);
    await _forget(record);
  }

  Future<void> _forget(DesktopCoreProcessRecord record) async {
    await _store.clear(pid: record.pid);
    _record = null;
  }

  NativeVpnCommandResult _failed(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    ygLogger('$operation Windows Core failed: $error\n$stackTrace');
    return commandFailed(error.toString());
  }
}
