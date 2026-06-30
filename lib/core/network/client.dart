import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/network/model.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NetClient {
  static final NetClient _singleton = NetClient._internal();

  factory NetClient() => _singleton;

  NetClient._internal() {
    _proxyClient.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (uri) => _proxy;
        client.authenticateProxy = (host, port, scheme, realm) {
          final auth = _proxyAuth;
          if (auth == null || !auth.isValid) {
            return Future.value(false);
          }
          client.addProxyCredentials(
            host,
            port,
            realm ?? "",
            HttpClientBasicCredentials(auth.user!, auth.pass!),
          );
          return Future.value(true);
        };
        return client;
      },
    );
  }

  //========================
  final _proxyClient = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
    ),
  );
  final _downloadClient = Dio(
    BaseOptions(connectTimeout: Duration(seconds: 10)),
  );

  String _proxyPort = "${NetConstants.defaultPingPort}";
  XrayInboundAccount? _proxyAuth;

  String get _proxy {
    return "PROXY ${NetConstants.proxyHost}:$_proxyPort";
  }

  Future<void> asyncInit() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final userAgent =
        'OneXray/${packageInfo.version} (${packageInfo.packageName}; build:${packageInfo.buildNumber}; ${Platform.operatingSystem})';
    final headers = <String, String>{'User-Agent': userAgent};
    _downloadClient.options.headers = headers;
  }

  static const _connectivityRetryCount = 3;

  Future<int?> ping(String port, String url, [XrayInboundAccount? auth]) async {
    if (url.trim().isEmpty) {
      return null;
    }
    _proxyPort = port;
    _proxyAuth = auth?.isValid == true ? auth : null;
    for (var i = 0; i < _connectivityRetryCount; i++) {
      try {
        final start = DateTime.now().millisecondsSinceEpoch;
        final res = await _proxyClient.get<Object?>(
          url,
          options: Options(responseType: ResponseType.plain),
        );
        if (res.statusCode != null &&
            res.statusCode! >= 200 &&
            res.statusCode! < 400) {
          return DateTime.now().millisecondsSinceEpoch - start;
        }
      } catch (e) {
        ygLogger("$e");
      }
      if (i < _connectivityRetryCount - 1) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return null;
  }

  Future<GeoLocation?> geoLocation(
    String port, [
    XrayInboundAccount? auth,
  ]) async {
    _proxyPort = port;
    _proxyAuth = auth?.isValid == true ? auth : null;
    for (var i = 0; i < _connectivityRetryCount; i++) {
      final location = await _geoLocation();
      if (location?.ipAddress != null) {
        return location;
      }
      if (i < _connectivityRetryCount - 1) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return null;
  }

  final _geoIPUrl = "https://ip-check-perf.radar.cloudflare.com/";

  Future<GeoLocation?> _geoLocation() async {
    try {
      final res = await _proxyClient.get<Map<String, dynamic>>(_geoIPUrl);
      if (res.statusCode == 200 && res.data != null) {
        final location = GeoLocation.fromJson(res.data!);
        return location;
      }
    } catch (e) {
      ygLogger("$e");
    }
    return null;
  }

  Future<String?> getText(String url) async {
    try {
      final res = await _downloadClient.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return res.data;
    } catch (e) {
      ygLogger("$e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getJson(String url) async {
    try {
      final res = await _downloadClient.get<Map<String, dynamic>>(url);
      return res.data;
    } catch (e) {
      ygLogger("$e");
      return null;
    }
  }

  Future<bool> downloadFile(String url, String savePath) async {
    try {
      await _downloadClient.download(url, savePath);
      return true;
    } catch (e) {
      ygLogger("$e");
      return false;
    }
  }
}
