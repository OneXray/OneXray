import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/ffi/linux_ffi_api.dart';
import 'package:onexray/core/ffi/windows_ffi_api.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/model/xray_standard.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/invoke_limits.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';

class AppHostApi {
  final _api = BridgeHostApi();

  static final AppHostApi _singleton = AppHostApi._internal();

  factory AppHostApi() => _singleton;

  AppHostApi._internal();

  // ===============
  final _errorResult = "error";
  var _tunFilesDir = "";

  Future<void> initTunFilesDir() async {
    if (AppPlatform.isLinux) {
      _tunFilesDir = await LinuxFfiApi().getTunFilesDir();
    } else if (AppPlatform.isWindows) {
      _tunFilesDir = await WindowsFfiApi().getTunFilesDir();
    } else {
      _tunFilesDir = await _api.getTunFilesDir();
    }
  }

  Future<bool?> cleanupStaleDesktopCore() async {
    try {
      if (AppPlatform.isLinux) {
        return LinuxFfiApi().cleanupStaleCore();
      } else if (AppPlatform.isWindows) {
        return WindowsFfiApi().cleanupStaleCore();
      }
    } catch (error, stackTrace) {
      _reportUnexpected('cleanupStaleDesktopCore', error, stackTrace);
      return false;
    }
    return null;
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

  Future<NativeVpnCommandResult> startVpn() async {
    try {
      return await _startVpn();
    } catch (error, stackTrace) {
      _reportUnexpected('startVpn', error, stackTrace);
      return _commandFailed();
    }
  }

  Future<NativeVpnCommandResult> _startVpn() async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().startVpn();
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().startVpn();
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

  Future<XrayJson> convertShareLinksToXrayJson(String text) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.convertShareLinksToXrayJson,
          payload: ConvertShareLinksToXrayJsonRequest(text).toJson(),
        ),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      if (resp.data != null) {
        if (resp.success) {
          final xrayJson = XrayJson.fromJson(resp.data!);
          return xrayJson;
        }
      }
    } catch (error, stackTrace) {
      _reportUnexpected('convertShareLinksToXrayJson', error, stackTrace);
    }
    return XrayJsonStandard.standard;
  }

  Future<String> convertXrayJsonToShareLinks(XrayJson xrayJson) async {
    try {
      final xrayJsonText = JsonTool.encoder.convert(xrayJson.toJson());
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

  Future<int> ping(
    String configPath,
    int timeout,
    String url,
    String proxy,
  ) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.ping,
          payload: PingRequest(configPath, timeout, url, proxy).toJson(),
        ),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      ygLogger(
        "ping result success:${resp.success} data:${resp.data} error:${resp.error}",
      );
      if (resp.data != null) {
        final data = PingResponse.fromJson(resp.data!);
        if (data.delay != null) {
          ygLogger("ping delay: ${data.delay}");
          return data.delay!;
        }
      }
    } catch (error, stackTrace) {
      _reportUnexpected('ping', error, stackTrace);
    }
    return PingDelayConstants.error;
  }

  Future<String> testXray(String configPath) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.testXray,
          payload: RunXrayRequest(configPath).toJson(),
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

  Future<String> runXray(String coreInvokeText) async {
    try {
      final request = _runXrayRequestFromText(coreInvokeText);
      if (AppPlatform.isLinux) {
        return await _runDesktopProxyCore(
          () => LinuxFfiApi().startProxyCore(request),
        );
      } else if (AppPlatform.isWindows) {
        return await _runDesktopProxyCore(
          () => WindowsFfiApi().startProxyCore(request),
        );
      }
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

  LibXrayRunConfig _runXrayRequestFromText(String coreInvokeText) {
    return LibXrayRunConfig.fromInvokeText(coreInvokeText);
  }

  Future<String> _runDesktopProxyCore(Future<bool> Function() start) async {
    try {
      final started = await start();
      return started ? "" : _errorResult;
    } catch (error, stackTrace) {
      _reportUnexpected('runDesktopProxyCore', error, stackTrace);
      return _errorResult;
    }
  }

  Future<String> stopXray() async {
    if (AppPlatform.isLinux) {
      return await LinuxFfiApi().stopProxyCore();
    } else if (AppPlatform.isWindows) {
      return await WindowsFfiApi().stopProxyCore();
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

  Future<bool> getXrayState() async {
    if (AppPlatform.isLinux) {
      return await LinuxFfiApi().proxyCoreRunning();
    } else if (AppPlatform.isWindows) {
      return await WindowsFfiApi().proxyCoreRunning();
    }
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(method: LibXrayMethod.getXrayState),
      );
      final resp = LibXrayInvokeResponseParser.parse(res);
      if (resp.success && resp.data != null) {
        return GetXrayStateResponse.fromJson(resp.data!).running ?? false;
      }
    } catch (error, stackTrace) {
      _reportUnexpected('getXrayState', error, stackTrace);
    }
    return false;
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
      ygLogger(
        "libXray ${request.method?.name ?? 'unknown'} failed: ${response.error}",
      );
    }
    return responseJson;
  }

  // android
  Future<bool> checkVpnPermission() async {
    if (AppPlatform.isAndroid || AppPlatform.isIOS || AppPlatform.isMacOS) {
      try {
        final result = await _api.checkVpnPermission();
        return result;
      } catch (error, stackTrace) {
        _reportUnexpected('checkVpnPermission', error, stackTrace);
      }
    }
    return true;
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

  // macOS
  Future<bool> useSystemExtension() async {
    if (AppPlatform.isMacOS) {
      return await _api.useSystemExtension();
    } else {
      return false;
    }
  }

  // iOS
  Future<bool> setAppIcon(String appIcon) async {
    if (AppPlatform.isIOS) {
      try {
        return await _api.setAppIcon(appIcon);
      } catch (error, stackTrace) {
        _reportUnexpected('setAppIcon', error, stackTrace);
      }
    }
    return false;
  }

  Future<String> getCurrentAppIcon() async {
    if (AppPlatform.isIOS) {
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

  NativeVpnCommandResult _commandFailed() {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.failed,
      permission: _platformPermissionFailed(),
    );
  }

  void _reportUnexpected(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    ygReportError(error, stackTrace, reason: 'AppHostApi.$operation failed');
  }
}
