import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/network/model.dart';
import 'package:onexray/core/network/standard.dart';
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

  Future<GeoLocation> connectivityTest(String port, String url) async {
    _proxyPort = port;
    var location = GeoLocationStandard.standard;
    final retryCount = 3;
    for (var i = 0; i < retryCount; i++) {
      try {
        final start = DateTime.now().millisecondsSinceEpoch;
        location = await _geoLocation();
        if (location.ipAddress != null) {
          final end = DateTime.now().millisecondsSinceEpoch;
          location.delay = end - start;
          break;
        } else {
          await Future.delayed(Duration(seconds: 2));
        }
      } catch (e) {
        ygLogger("$e");
      }
    }
    return location;
  }

  final _geoIPUrl = "https://ip-check-perf.radar.cloudflare.com/";

  Future<GeoLocation> _geoLocation() async {
    var location = GeoLocationStandard.standard;
    try {
      final res = await _proxyClient.get<Map<String, dynamic>>(_geoIPUrl);
      if (res.statusCode == 200 && res.data != null) {
        final location = GeoLocation.fromJson(res.data!);
        return location;
      }
    } catch (e) {
      ygLogger("$e");
    }
    return location;
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
