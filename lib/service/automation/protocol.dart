import 'dart:convert';

abstract final class AutomationProtocol {
  static const apiVersion = 'v1';
  static const appName = 'OneXray';

  static const authHeader = 'authorization';
  static const authScheme = 'Bearer';

  static const healthPath = '/v1/health';
  static const statusPath = '/v1/status';
  static const importPath = '/v1/import';
  static const vpnStartPath = '/v1/vpn/start';
  static const vpnStopPath = '/v1/vpn/stop';

  static const sessionFileName = 'automation-session.json';
}

abstract final class AutomationErrorCode {
  static const appNotRunning = 'app_not_running';
  static const apiUnavailable = 'api_unavailable';
  static const unauthorized = 'unauthorized';
  static const invalidResponse = 'invalid_response';
  static const staleSession = 'stale_session';
  static const unsupportedPlatform = 'unsupported_platform';
  static const invalidRequest = 'invalid_request';
  static const invalidSubscription = 'invalid_subscription';
  static const invalidConfigId = 'invalid_config_id';
  static const importFailed = 'import_failed';
  static const internalError = 'internal_error';
  static const notImplemented = 'not_implemented';
}

class AutomationException implements Exception {
  final String code;
  final String message;
  final Object? detail;

  const AutomationException(this.code, this.message, {this.detail});

  Map<String, dynamic> toJson() => {
    'ok': false,
    'code': code,
    'message': message,
    if (detail != null) 'detail': detail.toString(),
  };

  @override
  String toString() => '$code: $message';
}

class AutomationEnvelope {
  final bool ok;
  final Map<String, dynamic>? data;
  final String? code;
  final String? message;

  const AutomationEnvelope({
    required this.ok,
    this.data,
    this.code,
    this.message,
  });

  factory AutomationEnvelope.success(Map<String, dynamic> data) =>
      AutomationEnvelope(ok: true, data: data);

  factory AutomationEnvelope.error(String code, String message) =>
      AutomationEnvelope(ok: false, code: code, message: message);

  factory AutomationEnvelope.fromJson(Map<String, dynamic> json) =>
      AutomationEnvelope(
        ok: json['ok'] == true,
        data: json['data'] is Map<String, dynamic>
            ? json['data'] as Map<String, dynamic>
            : null,
        code: json['code'] as String?,
        message: json['message'] as String?,
      );

  Map<String, dynamic> toJson() => ok
      ? {'ok': true, 'data': data ?? <String, dynamic>{}}
      : {'ok': false, 'code': code, 'message': message};

  String encode() => jsonEncode(toJson());
}

class AutomationSession {
  final String apiVersion;
  final String host;
  final int port;
  final String token;
  final int pid;
  final String appVersion;
  final DateTime createdAt;

  const AutomationSession({
    required this.apiVersion,
    required this.host,
    required this.port,
    required this.token,
    required this.pid,
    required this.appVersion,
    required this.createdAt,
  });

  factory AutomationSession.fromJson(Map<String, dynamic> json) {
    return AutomationSession(
      apiVersion:
          json['apiVersion'] as String? ?? AutomationProtocol.apiVersion,
      host: json['host'] as String? ?? '127.0.0.1',
      port: json['port'] as int,
      token: json['token'] as String,
      pid: json['pid'] as int? ?? 0,
      appVersion: json['appVersion'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Uri get baseUri => Uri(scheme: 'http', host: host, port: port);

  Map<String, dynamic> toJson() => {
    'apiVersion': apiVersion,
    'host': host,
    'port': port,
    'token': token,
    'pid': pid,
    'appVersion': appVersion,
    'createdAt': createdAt.toIso8601String(),
  };
}
