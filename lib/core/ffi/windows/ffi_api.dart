import 'package:onexray/core/ffi/base_ffi_api.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/pigeon/model_writer.dart';
import 'package:onexray/core/tools/logger.dart';

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
      return commandSuccess();
    }
    try {
      var state = await _native.getVpnStatus();
      _rememberSnapshot(state);
      if ((state.status == WindowsVpnStatus.connected ||
              state.status == WindowsVpnStatus.connecting) &&
          !await _hasValidSession(state.snapshotToken)) {
        state = await _native.stopVpn();
        _rememberSnapshot(state);
      }
      await _emitWindowsStatus(state.status);
      return commandSuccess();
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
              configPath: coreConfig.configPath,
              runtimePath: coreConfig.runtimePath,
            ),
          ),
        ],
      );

      await updateVpnStatus(VpnStatus.connecting);
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
      _snapshotToken = token;
      await _emitWindowsStatus(state.status);
      return commandSuccess();
    } catch (error, stackTrace) {
      ygLogger('start Windows VPN failed: $error\n$stackTrace');
      await _rollbackStart(providerStartInvoked);
      return commandFailed(error.toString());
    } finally {
      _starting = false;
    }
  }

  @override
  Future<NativeVpnCommandResult> stopVpn() async {
    try {
      final state = await _native.stopVpn();
      _rememberSnapshot(state);
      await _emitWindowsStatus(state.status);
      return commandSuccess();
    } catch (error, stackTrace) {
      ygLogger('stop Windows VPN failed: $error\n$stackTrace');
      return commandFailed(error.toString());
    }
  }

  Future<void> _rollbackStart(bool providerStartInvoked) async {
    if (!providerStartInvoked) {
      await updateVpnStatus(VpnStatus.disconnected);
      return;
    }
    try {
      final state = await _native.stopVpn();
      _rememberSnapshot(state);
      await _emitWindowsStatus(state.status);
    } catch (error) {
      ygLogger('rollback Windows VPN provider failed: $error');
    }
  }

  void _rememberSnapshot(WindowsVpnProfileState state) {
    _snapshotToken = state.status == WindowsVpnStatus.disconnected
        ? null
        : state.snapshotToken;
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

  Future<({String configPath, String? runtimePath})> _publishCoreConfig(
    LibXrayRunConfig request,
  ) async {
    final paths = await materializeRunXrayConfig(request);
    if (paths == null) throw const FormatException('xrayJson is empty');
    return paths;
  }

  Future<void> _emitWindowsStatus(WindowsVpnStatus status) {
    return updateVpnStatus(switch (status) {
      WindowsVpnStatus.disconnecting => VpnStatus.disconnecting,
      WindowsVpnStatus.disconnected => VpnStatus.disconnected,
      WindowsVpnStatus.connecting => VpnStatus.connecting,
      WindowsVpnStatus.connected => VpnStatus.connected,
    });
  }
}
