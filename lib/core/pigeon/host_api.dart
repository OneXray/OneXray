import 'dart:convert';

import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/ffi/linux_ffi_api.dart';
import 'package:onexray/core/ffi/windows_ffi_api.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/core/tools/logger.dart';
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

  Future<void> readVpnStatus() async {
    try {
      await _readVpnStatus();
    } catch (_) {}
  }

  Future<void> _readVpnStatus() async {
    if (AppPlatform.isLinux) {
      await LinuxFfiApi().readVpnStatus();
    } else if (AppPlatform.isWindows) {
      await WindowsFfiApi().readVpnStatus();
    } else {
      await _api.readVpnStatus();
    }
  }

  Future<void> startVpn() async {
    try {
      await _startVpn();
    } catch (_) {}
  }

  Future<void> _startVpn() async {
    if (AppPlatform.isLinux) {
      await LinuxFfiApi().startVpn();
    } else if (AppPlatform.isWindows) {
      await WindowsFfiApi().startVpn();
    } else {
      await _api.startVpn();
    }
  }

  Future<void> stopVpn() async {
    try {
      await _stopVpn();
    } catch (_) {}
  }

  Future<void> _stopVpn() async {
    if (AppPlatform.isLinux) {
      await LinuxFfiApi().stopVpn();
    } else if (AppPlatform.isWindows) {
      await WindowsFfiApi().stopVpn();
    } else {
      await _api.stopVpn();
    }
  }

  String get tunFilesDir => _tunFilesDir;

  Future<List<int>> getFreePorts(int num) async {
    try {
      final res = await _getFreePorts(num);
      final resp = parseCallResponse(res);
      if (resp.success != null && resp.data != null) {
        if (resp.success!) {
          final data = resp.data as Map<String, dynamic>;
          final ports = GetFreePortsResponse.fromJson(data);
          if (ports.ports != null) {
            return ports.ports!;
          }
        }
      }
    } catch (_) {}
    return [];
  }

  Future<String> _getFreePorts(int num) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().getFreePorts(num);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().getFreePorts(num);
    } else {
      return _api.getFreePorts(num);
    }
  }

  Future<XrayJson> convertShareLinksToXrayJson(String text) async {
    try {
      final request = encodeStringRequest(text);
      final res = await _convertShareLinksToXrayJson(request);
      final resp = parseCallResponse(res);
      if (resp.success != null && resp.data != null) {
        if (resp.success!) {
          final data = resp.data as Map<String, dynamic>;
          final xrayJson = XrayJson.fromJson(data);
          return xrayJson;
        }
      }
    } catch (e) {
      ygLogger("$e");
    }
    return XrayJsonStandard.standard;
  }

  Future<String> _convertShareLinksToXrayJson(String base64Text) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().convertShareLinksToXrayJson(base64Text);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().convertShareLinksToXrayJson(base64Text);
    } else {
      return _api.convertShareLinksToXrayJson(base64Text);
    }
  }

  Future<String> convertXrayJsonToShareLinks(XrayJson xrayJson) async {
    try {
      final requestMap = xrayJson.toJson();
      final base64Text = JsonTool.encodeJsonToBase64(requestMap);
      final res = await _convertXrayJsonToShareLinks(base64Text);
      final resp = parseCallResponse(res);
      if (resp.success != null && resp.data != null) {
        if (resp.success!) {
          final data = resp.data as String;
          return data;
        }
      }
    } catch (e) {
      ygLogger("$e");
    }
    return "";
  }

  Future<String> _convertXrayJsonToShareLinks(String base64Text) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().convertXrayJsonToShareLinks(base64Text);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().convertXrayJsonToShareLinks(base64Text);
    } else {
      return _api.convertXrayJsonToShareLinks(base64Text);
    }
  }

  Future<String> countGeoData(CountGeoDataRequest request) async {
    try {
      final requestMap = request.toJson();
      final base64Text = JsonTool.encodeJsonToBase64(requestMap);
      final res = await _countGeoData(base64Text);
      final resp = parseCallResponse(res);
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

  Future<String> _countGeoData(String base64Text) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().countGeoData(base64Text);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().countGeoData(base64Text);
    } else {
      return _api.countGeoData(base64Text);
    }
  }

  Future<ReadGeoFilesResponse> readGeoFiles(String base64Text) async {
    try {
      final res = await _readGeoFiles(base64Text);
      final resp = parseCallResponse(res);
      if (resp.success != null) {
        if (resp.success!) {
          final data = resp.data as Map<String, dynamic>;
          final geoFiles = ReadGeoFilesResponse.fromJson(data);
          return geoFiles;
        } else {
          if (resp.error != null) {
            return ReadGeoFilesResponse(null, null);
          }
        }
      }
    } catch (e) {
      ygLogger("$e");
    }
    return ReadGeoFilesResponse(null, null);
  }

  Future<String> _readGeoFiles(String base64Text) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().readGeoFiles(base64Text);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().readGeoFiles(base64Text);
    } else {
      return _api.readGeoFiles(base64Text);
    }
  }

  Future<int> ping(
    String datDir,
    String configPath,
    int timeout,
    String url,
    String proxy,
  ) async {
    try {
      final request = PingRequest(
        datDir,
        configPath,
        timeout,
        url,
        proxy,
      ).toJson();
      final base64Text = JsonTool.encodeJsonToBase64(request);
      final res = await _ping(base64Text);
      final resp = parseCallResponse(res);
      ygLogger(
        "ping result sucess:${resp.success} data:${resp.data} error:${resp.error}",
      );
      if (resp.data != null && resp.data is int) {
        ygLogger("ping delay: ${resp.data}");
        return resp.data as int;
      }
    } catch (e) {
      ygLogger("$e");
    }
    return PingDelayConstants.unknown;
  }

  Future<String> _ping(String base64Text) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().ping(base64Text);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().ping(base64Text);
    } else {
      return _api.ping(base64Text);
    }
  }

  Future<String> testXray(String datDir, String configPath) async {
    try {
      final request = RunXrayRequest(datDir, null, configPath).toJson();
      final base64Text = JsonTool.encodeJsonToBase64(request);
      final res = await _testXray(base64Text);
      final resp = parseCallResponse(res);
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

  Future<String> _testXray(String base64Text) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().testXray(base64Text);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().testXray(base64Text);
    } else {
      return _api.testXray(base64Text);
    }
  }

  Future<String> runXray(
    String datDir,
    String mphCachePath,
    String configPath,
  ) async {
    try {
      final request = RunXrayRequest(datDir, mphCachePath, configPath).toJson();
      final base64Text = JsonTool.encodeJsonToBase64(request);
      final res = await _runXray(base64Text);
      final resp = parseCallResponse(res);
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

  Future<String> _runXray(String base64Text) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().runXray(base64Text);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().runXray(base64Text);
    } else {
      return _api.runXray(base64Text);
    }
  }

  Future<String> stopXray() async {
    try {
      final res = await _stopXray();
      final resp = parseCallResponse(res);
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

  Future<String> _stopXray() async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().stopXray();
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().stopXray();
    } else {
      return _api.stopXray();
    }
  }

  Future<String> xrayVersion() async {
    try {
      final res = await _xrayVersion();
      final resp = parseCallResponse(res);
      if (resp.success != null && resp.data != null) {
        if (resp.success!) {
          return resp.data! as String;
        }
      }
    } catch (_) {}
    return "";
  }

  Future<String> _xrayVersion() async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().xrayVersion();
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().xrayVersion();
    } else {
      return _api.xrayVersion();
    }
  }

  Future<String> buildMphCache(
    String datDir,
    String mphCachePath,
    String configPath,
  ) async {
    try {
      final request = RunXrayRequest(datDir, mphCachePath, configPath).toJson();
      final base64Text = JsonTool.encodeJsonToBase64(request);
      final res = await _buildMphCache(base64Text);
      final resp = parseCallResponse(res);
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

  Future<String> _buildMphCache(String base64Text) async {
    if (AppPlatform.isLinux) {
      return LinuxFfiApi().buildMphCache(base64Text);
    } else if (AppPlatform.isWindows) {
      return WindowsFfiApi().buildMphCache(base64Text);
    } else {
      return _api.buildMphCache(base64Text);
    }
  }

  CallResponse parseCallResponse(String res) {
    final data = JsonTool.decodeBase64ToJson(res);
    final resp = CallResponse.fromJson(data);
    return resp;
  }

  String encodeStringRequest(String request) {
    final data = utf8.encode(request);
    final base64Text = base64Encode(data);
    return base64Text;
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
}
