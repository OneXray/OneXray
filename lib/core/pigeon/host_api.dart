import 'dart:typed_data';

import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/core/ffi/linux_ffi_api.dart';
import 'package:onexray/core/ffi/windows/ffi_api.dart';
import 'package:onexray/core/ffi/windows/model.dart';
import 'package:onexray/core/ffi/windows/native_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/invoke_limits.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';

class AppHostApi {
  Future<AppleVpnCapabilities> appleVpnCapabilities() =>
      _api.appleVpnCapabilities();
  final _api = BridgeHostApi();
  final _windows = WindowsNativeApi();

  static final AppHostApi _singleton = AppHostApi._internal();

  factory AppHostApi() => _singleton;

  AppHostApi._internal();

  // ===============
  final _errorResult = "error";
  var _tunFilesDir = "";
  var _windowsPackageAvailable = false;

  bool get windowsPackageAvailable => _windowsPackageAvailable;
  bool get needsVpnStatusPolling =>
      AppPlatform.isWindows ||
      (AppPlatform.isLinux && LinuxFfiApi().needsVpnStatusPolling);

  Future<void> initTunFilesDir() async {
    if (AppPlatform.isLinux) {
      _tunFilesDir = await LinuxFfiApi().getTunFilesDir();
    } else if (AppPlatform.isWindows) {
      try {
        final environment = await _windows.getEnvironment();
        _tunFilesDir = environment.packageLocalDataDir;
        WindowsFfiApi().usePackageLocalDataDir(_tunFilesDir);
        _windowsPackageAvailable = true;
      } catch (error, stackTrace) {
        _windowsPackageAvailable = false;
        _reportUnexpected('getWindowsEnvironment', error, stackTrace);
        _tunFilesDir = await WindowsFfiApi().getTunFilesDir();
      }
    } else {
      _tunFilesDir = await _api.getTunFilesDir();
    }
  }

  Future<bool?> cleanupStaleDesktopCore() async {
    if (!AppPlatform.isLinux) {
      return null;
    }
    try {
      return await LinuxFfiApi().cleanupStaleCore();
    } catch (error, stackTrace) {
      _reportUnexpected('cleanupStaleDesktopCore', error, stackTrace);
      return false;
    }
  }

  Future<NativeVpnCommandResult> readVpnStatus() async {
    try {
      return await _readVpnStatus();
    } catch (error, stackTrace) {
      _reportUnexpected('readVpnStatus', error, stackTrace);
      return _commandFailed();
    }
  }

  Future<NativeVpnCommandResult> _readVpnStatus() async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().readVpnStatus();
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().readVpnStatus();
    } else {
      return _api.readVpnStatus();
    }
  }

  Future<NativeVpnCommandResult> startVpn({
    String? windowsConfigYaml,
    WindowsVpnNetworkSettings? windowsNetworkSettings,
    WindowsVpnPolicy windowsPolicy = const WindowsVpnPolicy(
      alwaysOn: false,
      allowLocalNetwork: true,
      excludedCidrs: [],
    ),
  }) async {
    try {
      return await _startVpn(
        windowsConfigYaml,
        windowsNetworkSettings,
        windowsPolicy,
      );
    } catch (error, stackTrace) {
      _reportUnexpected('startVpn', error, stackTrace);
      return _commandFailed(error.toString());
    }
  }

  Future<NativeVpnCommandResult> _startVpn(
    String? windowsConfigYaml,
    WindowsVpnNetworkSettings? windowsNetworkSettings,
    WindowsVpnPolicy windowsPolicy,
  ) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().startVpn();
    } else if (AppPlatform.isWindows) {
      if (!_windowsPackageAvailable) {
        return _commandFailed('Windows package identity is unavailable');
      }
      return WindowsFfiApi().startVpn(
        configYaml: windowsConfigYaml,
        networkSettings: windowsNetworkSettings,
        policy: windowsPolicy,
      );
    } else {
      return _api.startVpn();
    }
  }

  Future<NativeVpnCommandResult> stopVpn() async {
    try {
      return await _stopVpn();
    } catch (error, stackTrace) {
      _reportUnexpected('stopVpn', error, stackTrace);
      return _commandFailed();
    }
  }

  Future<NativeVpnCommandResult> _stopVpn() async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().stopVpn();
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().stopVpn();
    } else {
      return _api.stopVpn();
    }
  }

  String get tunFilesDir => _tunFilesDir;

  Future<List<int>> getFreePorts(int num) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.getFreePorts,
          payload: GetFreePortsRequest(num).toJson(),
        ),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      if (resp.data != null) {
        if (resp.success) {
          final ports = GetFreePortsResponse.fromJson(resp.data!);
          if (ports.ports != null) {
            return ports.ports!;
          }
        }
      }
    } catch (error, stackTrace) {
      _reportUnexpected('getFreePorts', error, stackTrace);
    }
    return [];
  }

  Future<ConvertShareLinksReport> convertShareLinksToXrayJsonReport(
    String text, {
    String? ageSecretKey,
  }) async {
    final key = ageSecretKey?.trim();
    final response = LibXrayInvokeResponseParser.parse(
      await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.convertShareLinksToXrayJson,
          payload: ConvertShareLinksToXrayJsonRequest(
            text,
            age: key == null || key.isEmpty ? null : AgeDecryptConfig(key),
            includeStats: true,
          ).toJson(),
        ),
      ),
    );
    final data = response.data;
    if (data != null && data['config'] is Map<String, dynamic>) {
      // An identified document may report zero usable items as a structured
      // failure. It is useful feedback, never permission to overwrite assets.
      final report = ConvertShareLinksReport.fromJson(data);
      final outbounds = report.config['outbounds'];
      if (report.usableCount == null ||
          report.failedCount == null ||
          report.usableCount! < 0 ||
          report.failedCount! < 0 ||
          outbounds is! List ||
          outbounds.length != report.usableCount ||
          (!response.success && report.usableCount != 0)) {
        throw const FormatException('Invalid import statistics');
      }
      return report;
    }
    if (response.success && data != null && data['outbounds'] is List) {
      return ConvertShareLinksReport(
        data,
      ); // Older native library: count unknown.
    }
    throw LibXrayInvokeException(response.error);
  }

  Future<GenerateAgeKeyPairResponse> generateAgeKeyPair({
    AgeKeyType keyType = AgeKeyType.x25519,
  }) async {
    final res = await _invoke(
      LibXrayInvokeRequest(
        method: LibXrayMethod.generateAgeKeyPair,
        payload: GenerateAgeKeyPairRequest(keyType).toJson(),
      ),
    );
    final resp = LibXrayInvokeResponseParser.parse(res);
    if (resp.success && resp.data != null) {
      final response = GenerateAgeKeyPairResponse.fromJson(resp.data!);
      if ((response.secretKey?.isNotEmpty ?? false) &&
          (response.publicKey?.isNotEmpty ?? false)) {
        return response;
      }
    }
    throw LibXrayInvokeException(resp.error);
  }

  Future<String> convertXrayJsonToShareLinks(
    Map<String, dynamic> xrayJson,
  ) async {
    try {
      final xrayJsonText = JsonTool.encoder.convert(xrayJson);
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.convertXrayJsonToShareLinks,
          payload: ConvertXrayJsonToShareLinksRequest(xrayJsonText).toJson(),
        ),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      if (resp.data != null) {
        if (resp.success) {
          final data = ConvertXrayJsonToShareLinksResponse.fromJson(resp.data!);
          return data.links ?? "";
        }
      }
    } catch (error, stackTrace) {
      _reportUnexpected('convertXrayJsonToShareLinks', error, stackTrace);
    }
    return "";
  }

  Future<String> countGeoData(CountGeoDataRequest request) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.countGeoData,
          payload: request.toJson(),
        ),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      if (resp.success) {
        return "";
      }
      return resp.error;
    } catch (error, stackTrace) {
      _reportUnexpected('countGeoData', error, stackTrace);
    }
    return _errorResult;
  }

  Future<PingBatchResponse?> pingBatch(PingBatchRequest request) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.pingBatch,
          payload: request.toJson(),
        ),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      ygLogger("pingBatch result success:${resp.success} error:${resp.error}");
      if (resp.success && resp.data != null) {
        return PingBatchResponse.fromJson(resp.data!);
      }
    } catch (error, stackTrace) {
      _reportUnexpected('pingBatch', error, stackTrace);
    }
    return null;
  }

  Future<String> testXray(String xrayJson, {bool buildOnly = false}) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.testXray,
          payload: TestXrayRequest(
            xrayJson,
            buildOnly: buildOnly ? true : null,
          ).toJson(),
        ),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      if (resp.success) {
        return "";
      }
      return resp.error;
    } catch (error, stackTrace) {
      _reportUnexpected('testXray', error, stackTrace);
    }
    return _errorResult;
  }

  Future<CheckRouteResponse> checkRoute(CheckRouteRequest request) async {
    final result = await _invoke(
      LibXrayInvokeRequest(
        method: LibXrayMethod.checkRoute,
        payload: request.toJson(),
      ),
    );
    final response = LibXrayInvokeResponseParser.parse(result);
    if (!response.success || response.data == null) {
      throw LibXrayInvokeException(response.error);
    }
    return CheckRouteResponse.fromJson(response.data!);
  }

  Future<int> probeXray(
    String xrayJson, {
    required String url,
    required int timeout,
    String inboundTag = 'tunIn',
  }) async {
    final result = await _invoke(
      LibXrayInvokeRequest(
        method: LibXrayMethod.testXray,
        payload: TestXrayRequest(
          xrayJson,
          url: url,
          timeout: timeout,
          inboundTag: inboundTag,
        ).toJson(),
      ),
    );
    final response = LibXrayInvokeResponseParser.parse(result);
    final delay = response.data?['delay'];
    if (!response.success || delay is! int || delay < 0) {
      throw const FormatException('Configuration URL probe failed');
    }
    return delay;
  }

  Future<String> runXray(String coreInvokeText) async {
    if (!AppPlatform.isIOS) {
      return _errorResult;
    }
    try {
      final request = LibXrayRunConfig.fromInvokeText(coreInvokeText);
      final res = await _invoke(request.invoke);
      final resp = LibXrayInvokeResponseParser.parse(res);
      if (resp.success) {
        return "";
      }
      return resp.error;
    } catch (error, stackTrace) {
      _reportUnexpected('runXray', error, stackTrace);
    }
    return _errorResult;
  }

  /// Reads only the two fixed logs inside a System Extension plan directory.
  Future<NativeLogChunk?> readLog({
    required String planId,
    required bool access,
    required int offset,
    required int limit,
  }) async {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(planId) ||
        offset < -1 ||
        limit <= 0 ||
        limit > 1024 * 1024) {
      throw const FormatException('Invalid log request');
    }
    if (!AppPlatform.isMacOS) {
      throw UnsupportedError('logRequiresSystemExtension');
    }
    final chunk = await _api
        .readLog(planId, access, offset, limit)
        .timeout(const Duration(seconds: 8));
    if (chunk != null &&
        (chunk.offset < 0 ||
            chunk.size < chunk.offset ||
            chunk.data.length > limit ||
            chunk.data.length > chunk.size - chunk.offset ||
            chunk.fileId.isEmpty ||
            chunk.fileId.length > 128)) {
      throw const FormatException('Invalid log response');
    }
    if (chunk != null) {
      final expectedOffset = offset == -1
          ? (chunk.size > limit ? chunk.size - limit : 0)
          : (offset > chunk.size ? chunk.size : offset);
      if (chunk.offset != expectedOffset) {
        throw const FormatException('Invalid log response');
      }
    }
    return chunk;
  }

  Future<String> stopXray() async {
    if (!AppPlatform.isIOS) {
      return _errorResult;
    }
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(method: LibXrayMethod.stopXray),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      if (resp.success) {
        return "";
      }
      return resp.error;
    } catch (error, stackTrace) {
      _reportUnexpected('stopXray', error, stackTrace);
    }
    return _errorResult;
  }

  Future<String> xrayVersion() async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(method: LibXrayMethod.xrayVersion),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      if (resp.data != null) {
        if (resp.success) {
          return XrayVersionResponse.fromJson(resp.data!).version ?? "";
        }
      }
    } catch (error, stackTrace) {
      _reportUnexpected('xrayVersion', error, stackTrace);
    }
    return "";
  }

  Future<String> _invoke(LibXrayInvokeRequest request) async {
    final requestJson = JsonTool.encoder.convert(request.toJson());
    LibXrayInvokeLimits.validate(requestJson, "request");
    late final String responseJson;
    if (AppPlatform.isLinux) {
      responseJson = await LinuxFfiApi().invoke(requestJson);
    } else if (AppPlatform.isWindows) {
      responseJson = await WindowsFfiApi().invoke(requestJson);
    } else {
      responseJson = await _api.invoke(requestJson);
    }
    LibXrayInvokeLimits.validate(responseJson, "response");
    final response = LibXrayInvokeResponseParser.parse(responseJson);
    if (!response.success) {
      ygLogger("libXray ${request.method?.name ?? 'unknown'} failed");
    }
    return responseJson;
  }

  Future<PlatformPermissionResult> queryPlatformPermission() async {
    if (AppPlatform.isLinux || AppPlatform.isWindows) {
      return _platformPermissionNotRequired();
    }
    try {
      return await _api.queryPlatformPermission();
    } catch (error, stackTrace) {
      _reportUnexpected('queryPlatformPermission', error, stackTrace);
      return _platformPermissionFailed();
    }
  }

  Future<PlatformPermissionResult> requestPlatformPermission() async {
    if (AppPlatform.isLinux || AppPlatform.isWindows) {
      return _platformPermissionNotRequired();
    }
    try {
      return await _api.requestPlatformPermission();
    } catch (error, stackTrace) {
      _reportUnexpected('requestPlatformPermission', error, stackTrace);
      return _platformPermissionFailed();
    }
  }

  Future<List<AndroidAppInfo>> getInstalledApps() async {
    if (AppPlatform.isAndroid) {
      try {
        final result = await _api.getInstalledApps();
        return result;
      } catch (error, stackTrace) {
        _reportUnexpected('getInstalledApps', error, stackTrace);
      }
    }
    return [];
  }

  Future<Uint8List?> getAppIcon(String packageName) async {
    if (AppPlatform.isAndroid) {
      try {
        return await _api.getAppIcon(packageName);
      } catch (error, stackTrace) {
        _reportUnexpected('getAppIcon', error, stackTrace);
      }
    }
    return null;
  }

  // macOS
  Future<bool> useSystemExtension() async {
    if (AppPlatform.isMacOS) {
      return await _api.useSystemExtension();
    } else {
      return false;
    }
  }

  // Apple app icon
  Future<bool> setAppIcon(String appIcon) async {
    if (AppPlatform.isIOS || AppPlatform.isMacOS) {
      try {
        return await _api.setAppIcon(appIcon);
      } catch (error, stackTrace) {
        _reportUnexpected('setAppIcon', error, stackTrace);
      }
    }
    return false;
  }

  Future<String> getCurrentAppIcon() async {
    if (AppPlatform.isIOS || AppPlatform.isMacOS) {
      try {
        return await _api.getCurrentAppIcon();
      } catch (error, stackTrace) {
        _reportUnexpected('getCurrentAppIcon', error, stackTrace);
      }
    }
    return "";
  }

  PlatformPermissionResult _platformPermissionNotRequired() {
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.none,
      state: PlatformPermissionState.notRequired,
    );
  }

  PlatformPermissionResult _platformPermissionFailed() {
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.none,
      state: PlatformPermissionState.failed,
    );
  }

  NativeVpnCommandResult _commandFailed([String? message]) {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.failed,
      permission: _platformPermissionFailed(),
      message: message,
    );
  }

  void _reportUnexpected(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    // Native parser errors can contain the offending JSON or credentials.
    ygLogger(
      'AppHostApi.$operation failed (${error.runtimeType})\n$stackTrace',
    );
  }
}
