import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/windows/ffi_api.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/pigeon/model_writer.dart';
import 'package:onexray/core/tools/logger.dart';

class WindowsMsixFfiApi extends WindowsFfiApi {
  WindowsMsixFfiApi({WindowsNativeApi? native})
    : _native = native ?? WindowsNativeApi(),
      super.base();

  static const _coreRelativePath = 'OneXrayCore.exe';

  final WindowsNativeApi _native;
  bool _starting = false;
  String? _packageLocalDataDir;

  @override
  Future<String> getTunFilesDir() async => _packageLocalDataDir ??=
      (await _native.getEnvironment()).packageLocalDataDir;

  @override
  Future<void> ensureRuntime() async {
    await getTunFilesDir();
    await checkRuntimeFiles(const [
      'libXray.dll',
      _coreRelativePath,
      'vcore.dll',
      'vcore-windows-vpn-host.exe',
      'vcore-windows-session-host.exe',
    ]);
  }

  @override
  Future<NativeVpnCommandResult> readVpnStatus() async {
    if (_starting) {
      return commandSuccess(status: VpnStatus.connecting);
    }
    try {
      var state = await _native.getVpnStatus();
      if ((state.status == WindowsVpnStatus.connected ||
              state.status == WindowsVpnStatus.connecting) &&
          !await _hasValidSession(state.snapshotToken)) {
        state = await _native.stopVpn();
      }
      return commandSuccess(status: _status(state.status));
    } catch (error) {
      ygLogger('read Windows VPN status failed: $error');
      return commandFailed(error.toString());
    }
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
    if (configYaml == null || configYaml.isEmpty || networkSettings == null) {
      return commandFailed('Windows VPN settings are missing');
    }

    _starting = true;
    var providerStartInvoked = false;
    try {
      final request = await StartVpnRequestReader.readFromStartFile();
      final coreConfig = await _publishCoreConfig(readRunXrayRequest(request));
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

      await AppFlutterApi().vpnStatusChanged(VpnStatus.connecting);
      providerStartInvoked = true;
      final state = await _native.startVpn(
        configYaml,
        networkSettings,
        policy: policy,
        sessionBackend: backend,
      );
      final token = state.snapshotToken;
      if (token == null) {
        throw const FormatException('Windows VPN start returned no token');
      }
      request.snapshotToken = token;
      await request.writeToStartFile();
      await _emitWindowsStatus(state.status);
      return commandSuccess();
    } catch (error, stackTrace) {
      ygLogger('start Windows VPN failed: $error\n$stackTrace');
      await _cleanupFailedStart(providerStartInvoked);
      return commandFailed(error.toString());
    } finally {
      _starting = false;
    }
  }

  @override
  Future<NativeVpnCommandResult> stopVpn() async {
    try {
      final state = await _native.stopVpn();
      await _emitWindowsStatus(state.status);
      return commandSuccess();
    } catch (error, stackTrace) {
      ygLogger('stop Windows VPN failed: $error\n$stackTrace');
      return commandFailed(error.toString());
    }
  }

  Future<void> _cleanupFailedStart(bool providerStartInvoked) async {
    if (!providerStartInvoked) {
      await AppFlutterApi().vpnStatusChanged(VpnStatus.disconnected);
      return;
    }
    try {
      final state = await _native.stopVpn();
      await _emitWindowsStatus(state.status);
    } catch (error) {
      ygLogger('failed to clean up Windows VPN start: $error');
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

  Future<String> _publishCoreConfig(LibXrayRunConfig request) async {
    final paths = await materializeRunXrayConfig(request);
    if (paths == null) throw const FormatException('xrayJson is empty');
    return paths;
  }

  Future<void> _emitWindowsStatus(WindowsVpnStatus status) =>
      AppFlutterApi().vpnStatusChanged(_status(status));

  static VpnStatus _status(WindowsVpnStatus status) => switch (status) {
    WindowsVpnStatus.disconnecting => VpnStatus.disconnecting,
    WindowsVpnStatus.disconnected => VpnStatus.disconnected,
    WindowsVpnStatus.connecting => VpnStatus.connecting,
    WindowsVpnStatus.connected => VpnStatus.connected,
  };
}
