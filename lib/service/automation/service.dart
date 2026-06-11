import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/constants.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/automation/protocol.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/share/protocol.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

final class AutomationService {
  static final AutomationService _singleton = AutomationService._internal();

  factory AutomationService() => _singleton;

  AutomationService._internal();

  HttpServer? _server;
  AutomationSession? _session;
  final _sessionPaths = <String>{};

  Future<void> asyncInit() async {
    if (!AppPlatform.isDesktop || _server != null) {
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final token = _makeToken();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      _session = AutomationSession(
        apiVersion: AutomationProtocol.apiVersion,
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        token: token,
        pid: pid,
        appVersion: packageInfo.version,
        createdAt: DateTime.now(),
      );
      await _writeSessionFiles();
      unawaited(_serve(server));

      ygLogger(
        'Automation API listening on ${_session!.baseUri}; '
        'session=${_sessionPaths.join(', ')}',
      );
    } catch (e, stackTrace) {
      ygLogger('Automation API failed to start: $e\n$stackTrace');
    }
  }

  void dispose() {
    unawaited(_dispose());
  }

  Future<void> _dispose() async {
    final server = _server;
    _server = null;
    _session = null;
    if (server != null) {
      await server.close(force: true);
    }
    await _deleteSessionFiles();
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handleRequest(request));
      }
    } catch (e, stackTrace) {
      if (_server != null) {
        ygLogger('Automation API server stopped unexpectedly: $e\n$stackTrace');
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (!_authorized(request)) {
        await _writeError(
          request,
          HttpStatus.unauthorized,
          AutomationErrorCode.unauthorized,
          'The automation token is invalid.',
        );
        return;
      }

      final path = request.uri.path;
      switch (path) {
        case AutomationProtocol.healthPath:
          if (!await _checkMethod(request, 'GET')) {
            return;
          }
          await _writeSuccess(request, await _health());
          return;
        case AutomationProtocol.statusPath:
          if (!await _checkMethod(request, 'GET')) {
            return;
          }
          await _writeSuccess(request, await _status());
          return;
        case AutomationProtocol.importPath:
          if (!await _checkMethod(request, 'POST')) {
            return;
          }
          await _writeSuccess(request, await _importShareText(request));
          return;
        case AutomationProtocol.vpnStartPath:
          if (!await _checkMethod(request, 'POST')) {
            return;
          }
          await _writeSuccess(request, await _startVpn(request));
          return;
        case AutomationProtocol.vpnStopPath:
          if (!await _checkMethod(request, 'POST')) {
            return;
          }
          await _writeSuccess(request, await _stopVpn());
          return;
        default:
          await _writeError(
            request,
            HttpStatus.notFound,
            AutomationErrorCode.notImplemented,
            'Unsupported automation path: $path',
          );
      }
    } on AutomationException catch (e) {
      await _writeError(request, HttpStatus.badRequest, e.code, e.message);
    } catch (e, stackTrace) {
      ygLogger('Automation API error: $e\n$stackTrace');
      await _writeError(
        request,
        HttpStatus.internalServerError,
        AutomationErrorCode.internalError,
        'Automation API request failed.',
      );
    }
  }

  bool _authorized(HttpRequest request) {
    final session = _session;
    if (session == null) {
      return false;
    }
    final value = request.headers.value(HttpHeaders.authorizationHeader);
    return value == '${AutomationProtocol.authScheme} ${session.token}';
  }

  Future<bool> _checkMethod(HttpRequest request, String method) async {
    if (request.method == method) {
      return true;
    }
    await _writeError(
      request,
      HttpStatus.methodNotAllowed,
      AutomationErrorCode.invalidRequest,
      'Method ${request.method} is not allowed for ${request.uri.path}.',
    );
    return false;
  }

  Future<Map<String, dynamic>> _health() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return {
      'apiVersion': AutomationProtocol.apiVersion,
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'platform': Platform.operatingSystem,
      'pid': pid,
    };
  }

  Future<Map<String, dynamic>> _status() async {
    final eventState = AppEventBus.instance.state;
    final runningId = eventState.runningId;
    final runningName = await _configName(runningId);
    final startedAt = VpnService().vpnRunning
        ? await PreferencesKey().readVpnStartTimestamp()
        : null;
    final packageInfo = await PackageInfo.fromPlatform();

    return {
      'apiVersion': AutomationProtocol.apiVersion,
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'platform': Platform.operatingSystem,
      'vpn': {
        'running': VpnService().vpnRunning,
        'loading': eventState.vpnLoading,
        'runningId': runningId,
        'runningName': runningName,
        if (startedAt != null) 'startedAt': startedAt.toIso8601String(),
        if (startedAt != null)
          'durationSeconds': DateTime.now().difference(startedAt).inSeconds,
      },
      'settings': {'xraySettingId': eventState.xraySettingId},
    };
  }

  Future<Map<String, dynamic>> _importShareText(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final text = body['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const AutomationException(
        AutomationErrorCode.invalidRequest,
        'import requires non-empty text.',
      );
    }

    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);
    try {
      return await _readImportText(text.trim());
    } finally {
      eventBus.updateDownloading(false);
    }
  }

  Future<Map<String, dynamic>> _readImportText(String text) async {
    if (AppShareService().checkAppShare(text)) {
      final result = await () async {
        try {
          return await AppShareService().parseShareText(text);
        } catch (_) {
          throw const AutomationException(
            AutomationErrorCode.importFailed,
            'OneXray share content could not be imported.',
          );
        }
      }();
      final rows = result.item1;
      var configImported = 0;
      if (rows.isNotEmpty) {
        configImported = await ConfigWriter.writeRows(rows, null);
      }
      final success = result.item2 || configImported > 0;
      if (!success) {
        throw const AutomationException(
          AutomationErrorCode.importFailed,
          'No valid OneXray share content was imported.',
        );
      }
      return {
        'imported': configImported > 0 ? configImported : 1,
        'configImported': configImported,
        'source': 'oneXrayShare',
      };
    }

    if (text.startsWith('https://')) {
      final uri = Uri.tryParse(text);
      if (uri == null) {
        throw const AutomationException(
          AutomationErrorCode.invalidSubscription,
          'Subscription URL is invalid.',
        );
      }
      final success = await AppShareService().addSubscription(
        text,
        uri.fragment,
        true,
      );
      if (!success) {
        throw const AutomationException(
          AutomationErrorCode.importFailed,
          'Subscription download or import failed.',
        );
      }
      return {
        'imported': 1,
        'configImported': 0,
        'subscriptionImported': true,
        'source': 'httpsSubscription',
      };
    }

    final rows = await () async {
      try {
        return await XrayShareReader().parseShareText(text);
      } catch (_) {
        throw const AutomationException(
          AutomationErrorCode.importFailed,
          'Xray share links could not be imported.',
        );
      }
    }();
    final count = rows.isEmpty ? 0 : await ConfigWriter.writeRows(rows, null);
    if (count <= 0) {
      throw const AutomationException(
        AutomationErrorCode.importFailed,
        'No valid Xray share links were imported.',
      );
    }
    return {'imported': count, 'configImported': count, 'source': 'xrayShare'};
  }

  Future<Map<String, dynamic>> _startVpn(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final configId = body['configId'];
    if (configId != null && configId is! int) {
      throw const AutomationException(
        AutomationErrorCode.invalidRequest,
        'vpn start configId must be an integer.',
      );
    }

    if (configId != null && configId > DBConstants.defaultId) {
      final config = await AppDatabase().coreConfigDao.searchRow(configId);
      if (config == null) {
        throw AutomationException(
          AutomationErrorCode.invalidConfigId,
          'No config exists for id $configId.',
        );
      }
      await VpnService().startVpn(configId);
    } else {
      await VpnService().startDefaultVpn();
    }

    final response = <String, dynamic>{'requested': true};
    if (configId != null) {
      response['configId'] = configId;
    }
    return response;
  }

  Future<Map<String, dynamic>> _stopVpn() async {
    await VpnService().stopDefaultVpn();
    return {'requested': true};
  }

  Future<String> _configName(int id) async {
    if (id == DBConstants.defaultId) {
      return '';
    }
    final config = await AppDatabase().coreConfigDao.searchRow(id);
    return config?.name ?? '';
  }

  Future<void> _writeSuccess(
    HttpRequest request,
    Map<String, dynamic> data,
  ) async {
    await _writeJson(
      request,
      HttpStatus.ok,
      AutomationEnvelope.success(data).toJson(),
    );
  }

  Future<void> _writeError(
    HttpRequest request,
    int statusCode,
    String code,
    String message,
  ) async {
    await _writeJson(
      request,
      statusCode,
      AutomationEnvelope.error(code, message).toJson(),
    );
  }

  Future<void> _writeJson(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> data,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final text = await utf8.decodeStream(request);
    if (text.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final data = jsonDecode(text);
      if (data is Map<String, dynamic>) {
        return data;
      }
    } catch (_) {}
    throw const AutomationException(
      AutomationErrorCode.invalidRequest,
      'Request body must be a JSON object.',
    );
  }

  Future<void> _writeSessionFiles() async {
    final session = _session;
    if (session == null) {
      return;
    }

    final paths = <String>{
      p.join(VpnConstants.runDir, AutomationProtocol.sessionFileName),
      ...AutomationSessionPaths.candidates(),
    };
    for (final path in paths) {
      try {
        await Directory(p.dirname(path)).create(recursive: true);
        await File(path).writeAsString(jsonEncode(session.toJson()));
        _sessionPaths.add(path);
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _deleteSessionFiles() async {
    for (final path in _sessionPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        continue;
      }
    }
    _sessionPaths.clear();
  }

  String _makeToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
