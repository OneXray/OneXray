import 'dart:io';

import 'package:dio/dio.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/network/model.dart';
import 'package:onexray/core/network/user_agent.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

class NetClient {
  static final NetClient _singleton = NetClient._internal();

  factory NetClient() => _singleton;

  NetClient._internal();

  //========================
  final _downloadClient = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 60),
    ),
  );

  Future<void>? _initFuture;

  String get downloadUserAgent =>
      _downloadClient.options.headers['User-Agent']?.toString() ?? '';

  Future<void> asyncInit() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    final mode = await PreferencesKey().readDownloadUserAgentMode();
    await _applyUserAgentMode(mode);
  }

  Future<void> updateUserAgentMode(DownloadUserAgentMode mode) async {
    await asyncInit();
    await _applyUserAgentMode(mode);
  }

  Future<void> _applyUserAgentMode(DownloadUserAgentMode mode) async {
    final oneXrayUserAgent = await _oneXrayUserAgent();
    final userAgent = await DownloadUserAgent.resolve(
      mode: mode,
      oneXrayUserAgent: oneXrayUserAgent,
    );
    _downloadClient.options.headers['User-Agent'] = userAgent;
  }

  Future<String> _oneXrayUserAgent() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return 'OneXray/${packageInfo.version} '
          '(${packageInfo.packageName}; build:${packageInfo.buildNumber}; '
          '${Platform.operatingSystem})';
    } catch (error) {
      ygLogger('Unable to build the OneXray User-Agent: $error');
      return 'OneXray (${Platform.operatingSystem})';
    }
  }

  static const geoIPUrl = "https://ip-check-perf.radar.cloudflare.com/";

  static const _maxDownloadRedirects = 8;

  static bool isHttpsDownloadUri(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      uri.port > 0 &&
      uri.port <= 65535;

  Future<String?> getText(
    String url, {
    DownloadRequestHeaders? requestHeaders,
    bool httpsOnly = false,
  }) async {
    try {
      var uri = Uri.parse(url);
      if (httpsOnly && !isHttpsDownloadUri(uri)) {
        return null;
      }
      await asyncInit();
      final headers = requestHeaders?.toHttpHeaders();
      for (
        var redirectCount = 0;
        redirectCount <= _maxDownloadRedirects;
        redirectCount++
      ) {
        final res = await _downloadClient.getUri<String>(
          uri,
          options: Options(
            responseType: ResponseType.plain,
            headers: headers,
            followRedirects: false,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
        );
        final status = res.statusCode ?? 0;
        if (status < 300) {
          return res.data;
        }
        final location = res.headers.value(HttpHeaders.locationHeader);
        if (location == null ||
            location.isEmpty ||
            redirectCount == _maxDownloadRedirects) {
          return null;
        }
        uri = uri.resolve(location);
        if (httpsOnly && !isHttpsDownloadUri(uri)) {
          return null;
        }
      }
      return null;
    } catch (e) {
      // Subscription URLs can contain credentials; never log the request URI.
      ygLogger('text download failed (${e.runtimeType})');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getJson(String url) async {
    try {
      await asyncInit();
      final res = await _downloadClient.get<Map<String, dynamic>>(url);
      return res.data;
    } catch (e) {
      ygLogger("$e");
      return null;
    }
  }

  Future<bool> downloadFile(String url, String savePath) async {
    try {
      await asyncInit();
      await _downloadClient.download(url, savePath);
      return true;
    } catch (e) {
      ygLogger("$e");
      return false;
    }
  }
}
