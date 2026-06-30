import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/ffi/linux_ffi_api.dart';
import 'package:onexray/core/ffi/windows_ffi_api.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/standard.dart';

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

  Future<NativeVpnCommandResult> readVpnStatus() async {
    try {
      return await _readVpnStatus();
    } catch (e) {
      ygLogger("readVpnStatus error: $e");
      return _commandFailed(appLocalizationsNoContext().vpnCommandFailed);
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
    } catch (e) {
      ygLogger("startVpn error: $e");
      return _commandFailed(appLocalizationsNoContext().vpnStartFailed);
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
    } catch (e) {
      ygLogger("stopVpn error: $e");
      return _commandFailed(appLocalizationsNoContext().vpnStopFailed);
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
      final resp = parseLibXrayInvokeResponse(res);
      if (resp.success != null && resp.data != null) {
        if (resp.success!) {
          final ports = GetFreePortsResponse.fromJson(resp.data!);
          if (ports.ports != null) {
            return ports.ports!;
          }
        }
      }
    } catch (_) {}
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
      final resp = parseLibXrayInvokeResponse(res);
      if (resp.success != null && resp.data != null) {
        if (resp.success!) {
          final xrayJson = XrayJson.fromJson(resp.data!);
          return xrayJson;
        }
      }
    } catch (e) {
      ygLogger("$e");
    }
    return XrayJsonStandard.standard;
  }

  Future<String> convertXrayJsonToShareLinks(XrayJson xrayJson) async {
    try {
      final xrayJsonText = JsonTool.encoderForDb.convert(xrayJson.toJson());
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.convertXrayJsonToShareLinks,
          payload: ConvertXrayJsonToShareLinksRequest(xrayJsonText).toJson(),
        ),
      );
      final resp = parseLibXrayInvokeResponse(res);
      if (resp.success != null && resp.data != null) {
        if (resp.success!) {
          final data = ConvertXrayJsonToShareLinksResponse.fromJson(resp.data!);
          return data.links ?? "";
        }
      }
    } catch (e) {
      ygLogger("$e");
    }
    return "";
  }

  Future<String> countGeoData(
    String datDir,
    CountGeoDataRequest request,
  ) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.countGeoData,
          env: _datEnv(datDir),
          payload: request.toJson(),
        ),
      );
      final resp = parseLibXrayInvokeResponse(res);
      if (resp.success != null) {
        if (resp.success!) {
          return "";
        } else {
          if (resp.error != null) {
            return resp.error!;
          }
        }
      }
    } catch (_) {}
    return _errorResult;
  }

  Future<int> ping(
    String datDir,
    String configPath,
    int timeout,
    String url,
    String proxy,
  ) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.ping,
          env: _datEnv(datDir),
          payload: PingRequest(configPath, timeout, url, proxy).toJson(),
        ),
      );
      final resp = parseLibXrayInvokeResponse(res);
      ygLogger(
        "ping result sucess:${resp.success} data:${resp.data} error:${resp.error}",
      );
      if (resp.success == true && resp.data != null) {
        final data = PingResponse.fromJson(resp.data!);
        if (data.delay != null) {
          ygLogger("ping delay: ${data.delay}");
          return data.delay!;
        }
      }
    } catch (e) {
      ygLogger("$e");
    }
    return PingDelayConstants.unknown;
  }

  Future<String> testXray(String datDir, String configPath) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.testXray,
          env: _datEnv(datDir),
          payload: RunXrayRequest(configPath).toJson(),
        ),
      );
      final resp = parseLibXrayInvokeResponse(res);
      if (resp.success != null) {
        if (resp.success!) {
          return "";
        } else {
          if (resp.error != null) {
            return resp.error!;
          }
        }
      }
    } catch (e) {
      ygLogger("$e");
    }
    return _errorResult;
  }

  Future<String> runXray(String datDir, String configPath) async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(
          method: LibXrayMethod.runXray,
          env: _datEnv(datDir),
          payload: RunXrayRequest(configPath).toJson(),
        ),
      );
      final resp = parseLibXrayInvokeResponse(res);
      if (resp.success != null) {
        if (resp.success!) {
          return "";
        } else {
          if (resp.error != null) {
            return resp.error!;
          }
        }
      }
    } catch (_) {}
    return _errorResult;
  }

  Future<String> stopXray() async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(method: LibXrayMethod.stopXray),
      );
      final resp = parseLibXrayInvokeResponse(res);
      if (resp.success != null) {
        if (resp.success!) {
          return "";
        } else {
          if (resp.error != null) {
            return resp.error!;
          }
        }
      }
    } catch (_) {}
    return _errorResult;
  }

  Future<bool> getXrayState() async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(method: LibXrayMethod.getXrayState),
      );
      final resp = parseLibXrayInvokeResponse(res);
      if (resp.success == true && resp.data != null) {
        return GetXrayStateResponse.fromJson(resp.data!).running ?? false;
      }
    } catch (e) {
      ygLogger("getXrayState error: $e");
    }
    return false;
  }

  Future<String> xrayVersion() async {
    try {
      final res = await _invoke(
        LibXrayInvokeRequest(method: LibXrayMethod.xrayVersion),
      );
      final resp = parseLibXrayInvokeResponse(res);
      if (resp.success != null && resp.data != null) {
        if (resp.success!) {
          return XrayVersionResponse.fromJson(resp.data!).version ?? "";
        }
      }
    } catch (_) {}
    return "";
  }

  Future<String> _invoke(LibXrayInvokeRequest request) async {
    final requestJson = JsonTool.encoderForDb.convert(request.toJson());
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().invoke(requestJson);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().invoke(requestJson);
    } else {
      return _api.invoke(requestJson);
    }
  }

  LibXrayInvokeResponse parseLibXrayInvokeResponse(String res) {
    final data = JsonTool.decoder.convert(res) as Map<String, dynamic>;
    final resp = LibXrayInvokeResponse.fromJson(data);
    return resp;
  }

  LibXrayEnvJson _datEnv(String datDir) {
    return LibXrayEnvJson(assetLocation: datDir, certLocation: datDir);
  }

  // android
  Future<bool> checkVpnPermission() async {
    if (AppPlatform.isAndroid || AppPlatform.isIOS || AppPlatform.isMacOS) {
      try {
        final result = await _api.checkVpnPermission();
        return result;
      } catch (_) {}
    }
    return true;
  }

  Future<PlatformPermissionResult> queryPlatformPermission() async {
    if (AppPlatform.isLinux || AppPlatform.isWindows) {
      return _platformPermissionNotRequired();
    }
    try {
      return await _api.queryPlatformPermission();
    } catch (e) {
      ygLogger("queryPlatformPermission error: $e");
      return _platformPermissionFailed(
        appLocalizationsNoContext().vpnPlatformPermissionCheckFailed,
      );
    }
  }

  Future<PlatformPermissionResult> requestPlatformPermission() async {
    if (AppPlatform.isLinux || AppPlatform.isWindows) {
      return _platformPermissionNotRequired();
    }
    try {
      return await _api.requestPlatformPermission();
    } catch (e) {
      ygLogger("requestPlatformPermission error: $e");
      return _platformPermissionFailed(
        appLocalizationsNoContext().vpnPlatformPermissionCheckFailed,
      );
    }
  }

  Future<List<AndroidAppInfo>> getInstalledApps() async {
    if (AppPlatform.isAndroid) {
      try {
        final result = await _api.getInstalledApps();
        return result;
      } catch (_) {}
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
      } catch (_) {}
    }
    return false;
  }

  Future<String> getCurrentAppIcon() async {
    if (AppPlatform.isIOS) {
      try {
        return await _api.getCurrentAppIcon();
      } catch (_) {}
    }
    return "";
  }

  PlatformPermissionResult _platformPermissionNotRequired() {
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.none,
      state: PlatformPermissionState.notRequired,
    );
  }

  PlatformPermissionResult _platformPermissionFailed(String message) {
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.none,
      state: PlatformPermissionState.failed,
      message: message,
    );
  }

  NativeVpnCommandResult _commandFailed(String message) {
    return NativeVpnCommandResult(
      state: NativeVpnCommandState.failed,
      permission: _platformPermissionFailed(message),
      message: message,
    );
  }
}
