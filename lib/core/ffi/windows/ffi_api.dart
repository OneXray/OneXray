import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/pigeon/model_writer.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:path/path.dart' as p;

class WindowsFfiApi extends BaseFfiApi {
  static final WindowsFfiApi _singleton = WindowsFfiApi._internal();

  factory WindowsFfiApi() => _singleton;

  WindowsFfiApi._internal();

  static const _coreRelativePath = 'OneXrayCore.exe';

  final _native = WindowsNativeApi();
  bool _starting = false;
  String? _snapshotToken;
  String? _packageLocalDataDir;

  String? get snapshotToken => _snapshotToken;

  void usePackageLocalDataDir(String path) => _packageLocalDataDir = path;

  @override
  Future<String> getTunFilesDir() async =>
      _packageLocalDataDir ?? await super.getTunFilesDir();

  @override
  Future<NativeVpnCommandResult> readVpnStatus() async {
    if (_starting) {
      return _commandSuccess();
    }
    try {
      var state = await _native.getVpnStatus();
      _snapshotToken = state.snapshotToken;
      if ((state.status == WindowsVpnStatus.connected ||
              state.status == WindowsVpnStatus.connecting) &&
          !await _hasValidSession(state.snapshotToken)) {
        state = await _native.stopVpn();
        _snapshotToken = state.snapshotToken;
      }
      await _emitWindowsStatus(state.status);
      return _commandSuccess();
    } catch (error) {
      ygLogger('read Windows VPN status failed: $error');
      return _commandFailed(error.toString());
    }
  }

  @override
  Future<NativeVpnCommandResult> startVpn({
    String? configYaml,
    WindowsVpnNetworkSettings? networkSettings,
  }) async {
    if (configYaml == null || configYaml.isEmpty || networkSettings == null) {
      return _commandFailed('Windows VPN settings are missing');
    }

    _starting = true;
    var providerStartInvoked = false;
    try {
      final request = await StartVpnRequestReader.readFromStartFile();
      final coreConfig = await _publishCoreConfig(_readRunXrayRequest(request));
      final backend = WindowsSessionBackend(
        processes: [
          WindowsManagedProcess(
            executableRelativePath: _coreRelativePath,
            arguments: desktopCoreRunArguments(
              dns: networkSettings.dnsIpv4Address,
              interfaceName: request.tun?.autoOutboundsInterface ?? '',
              configPath: coreConfig,
            ),
          ),
        ],
      );

      await updateVpnStatus(VpnStatus.connecting);
      providerStartInvoked = true;
      final state = await _native.startVpn(
        configYaml,
        networkSettings,
        sessionBackend: backend,
      );
      final token = state.snapshotToken;
      if (token == null) {
        throw const FormatException('Windows VPN start returned no token');
      }
      request.snapshotToken = token;
      await request.writeToStartFile();
      _snapshotToken = token;
      await _emitWindowsStatus(state.status);
      return _commandSuccess();
    } catch (error, stackTrace) {
      ygLogger('start Windows VPN failed: $error\n$stackTrace');
      await _rollbackStart(providerStartInvoked);
      return _commandFailed(error.toString());
    } finally {
      _starting = false;
    }
  }

  @override
  Future<NativeVpnCommandResult> stopVpn() async {
    try {
      final state = await _native.stopVpn();
      _snapshotToken = state.snapshotToken;
      await _emitWindowsStatus(state.status);
      return _commandSuccess();
    } catch (error, stackTrace) {
      ygLogger('stop Windows VPN failed: $error\n$stackTrace');
      return _commandFailed(error.toString());
    }
  }

  Future<void> _rollbackStart(bool providerStartInvoked) async {
    if (!providerStartInvoked) {
      await updateVpnStatus(VpnStatus.disconnected);
      return;
    }
    try {
      final state = await _native.stopVpn();
      _snapshotToken = state.snapshotToken;
      await _emitWindowsStatus(state.status);
    } catch (error) {
      ygLogger('rollback Windows VPN provider failed: $error');
    }
  }

  Future<bool> _hasValidSession(String? snapshotToken) async {
    if (snapshotToken == null) {
      return false;
    }
    try {
      final request = await StartVpnRequestReader.readFromStartFile();
      return request.snapshotToken == snapshotToken;
    } catch (_) {
      return false;
    }
  }

  LibXrayRunConfig _readRunXrayRequest(StartVpnRequest request) {
    if (!EmptyTool.checkString(request.coreInvokeText)) {
      return LibXrayRunConfig(
        LibXrayInvokeRequest(
          method: LibXrayMethod.runXray,
          payload: RunXrayRequest(null).toJson(),
        ),
      );
    }
    return LibXrayRunConfig.fromInvokeText(request.coreInvokeText!);
  }

  Future<String> _publishCoreConfig(LibXrayRunConfig request) async {
    final xrayJson = request.request.xrayJson;
    if (xrayJson == null || xrayJson.isEmpty) {
      throw const FormatException('xrayJson is empty');
    }
    try {
      final bytes = utf8.encode(xrayJson);
      final digest = sha256.convert(bytes).toString();
      // ponytail: retain content-addressed inputs; add current+previous pruning
      // only if real configuration churn makes this directory material.
      final directory = Directory(
        p.join(await getTunFilesDir(), 'run', 'windows-session-backend'),
      );
      await directory.create(recursive: true);
      final target = File(p.join(directory.path, '$digest.json'));
      if (await target.exists()) {
        if (sha256.convert(await target.readAsBytes()).toString() != digest) {
          throw const FormatException('Windows Core config digest mismatch');
        }
        return target.path;
      }

      final staging = File('${target.path}.$pid.staging');
      if (await staging.exists()) {
        await staging.delete();
      }
      try {
        await staging.writeAsBytes(bytes, flush: true);
        await staging.rename(target.path);
      } on FileSystemException {
        if (!await target.exists() ||
            sha256.convert(await target.readAsBytes()).toString() != digest) {
          rethrow;
        }
      } finally {
        if (await staging.exists()) {
          await staging.delete();
        }
      }
      return target.path;
    } catch (error) {
      if (error is FormatException) {
        rethrow;
      }
      throw const FormatException('Unable to publish Windows Core config');
    }
  }

  Future<void> _emitWindowsStatus(WindowsVpnStatus status) {
    return updateVpnStatus(switch (status) {
      WindowsVpnStatus.disconnecting => VpnStatus.disconnecting,
      WindowsVpnStatus.disconnected => VpnStatus.disconnected,
      WindowsVpnStatus.connecting => VpnStatus.connecting,
      WindowsVpnStatus.connected => VpnStatus.connected,
    });
  }

  NativeVpnCommandResult _commandSuccess() {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.success,
      permission: _permissionNotRequired(),
    );
  }

  NativeVpnCommandResult _commandFailed(String message) {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.failed,
      permission: _permissionNotRequired(),
      message: message,
    );
  }

  PlatformPermissionResult _permissionNotRequired() {
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.none,
      state: PlatformPermissionState.notRequired,
    );
  }
}
