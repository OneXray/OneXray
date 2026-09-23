import 'dart:convert';
import 'dart:math';

import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/errors/failure.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/advanced/local_api/configuration.dart';
import 'package:onexray/service/advanced/local_api/server.dart';
import 'package:onexray/service/advanced/local_api/settings.dart';
import 'package:onexray/service/shared/command_serial_executor.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The opt-in desktop listener lives with the App, not with the VPN process.
final class LocalApiService {
  static final instance = LocalApiService._(
    readSettings: () => PreferencesKey().readLocalApi(),
    writeSettings: (value) => PreferencesKey().saveLocalApi(value),
    desktop: AppPlatform.isDesktop,
    info: () async => {
      'appVersion': (await PackageInfo.fromPlatform()).version,
      'coreVersion': await AppHostApi().xrayVersion(),
      'platform': AppPlatform.isMacOS
          ? 'macos'
          : AppPlatform.isWindows
          ? 'windows'
          : 'linux',
      'supportedKinds': ['outbound', 'routing', 'advanced-routing', 'raw'],
    },
    validate: LocalApiConfiguration().validate,
    compile: LocalApiConfiguration().compile,
  );

  final Future<Map<String, dynamic>?> Function() _readSettings;
  final Future<void> Function(Map<String, dynamic>) _writeSettings;
  final bool _desktop;
  final _commands = CommandSerialExecutor();
  late final LocalApiServer _server;
  LocalApiSettings? _settings;
  bool _paused = false;
  bool _stopped = false;
  String? _lastError;

  LocalApiService._({
    required this._readSettings,
    required this._writeSettings,
    required this._desktop,
    required Future<Map<String, dynamic>> Function() info,
    required LocalApiHandler validate,
    required LocalApiHandler compile,
  }) {
    _server = LocalApiServer(
      token: () => _settings?.token ?? '',
      available: () => !_paused && !_stopped && (_settings?.enabled ?? false),
      info: info,
      validate: validate,
      compile: compile,
    );
  }

  factory LocalApiService.forTesting({
    required Future<Map<String, dynamic>?> Function() readSettings,
    required Future<void> Function(Map<String, dynamic>) writeSettings,
    required Future<Map<String, dynamic>> Function() info,
    required LocalApiHandler validate,
    required LocalApiHandler compile,
    bool desktop = true,
  }) => LocalApiService._(
    readSettings: readSettings,
    writeSettings: writeSettings,
    desktop: desktop,
    info: info,
    validate: validate,
    compile: compile,
  );

  bool get listening => _server.listening;
  String? get lastError => _lastError;

  Future<LocalApiSettings> load() => _commands.run(_load);

  Future<LocalApiSettings> _load() async {
    if (_settings case final settings?) return settings;
    final json = await _readSettings();
    return _settings = json == null
        ? const LocalApiSettings()
        : LocalApiSettings.fromJson(json);
  }

  /// Auxiliary startup failure never blocks the normal App readiness gate.
  Future<void> start() {
    if (_paused) return Future.value();
    _stopped = false;
    _commands.resume();
    return _commands.run(() async {
      if (!_desktop) return;
      try {
        final settings = await _load();
        if (settings.enabled && !listening) {
          _server.attach(await LocalApiServer.bind(settings.port));
        }
        _lastError = null;
      } catch (error) {
        // Shared diagnostics retain the cause without echoing JSON source,
        // which may contain the persisted token when preferences are damaged.
        _lastError = 'Unable to start the local API: ${failureDetails(error)}';
      }
    });
  }

  Future<LocalApiSettings> configure({
    required bool enabled,
    required int port,
  }) => _commands.run(() async {
    _requireAvailable();
    if (port < 1024 || port > 65535) {
      throw const FormatException('Port must be between 1024 and 65535');
    }
    final current = await _load();
    final next = LocalApiSettings(
      enabled: enabled,
      port: port,
      token: enabled && current.token.isEmpty ? _newToken() : current.token,
    );
    // Bind before committing the preference: conflicts leave the current
    // endpoint/token untouched and do not claim that the new port works.
    final candidate = enabled && (!listening || _server.port != port)
        ? await LocalApiServer.bind(port)
        : null;
    try {
      await _writeSettings(next.toJson());
    } catch (_) {
      await candidate?.close(force: true);
      rethrow;
    }
    _settings = next;
    if (!enabled) {
      await _server.close();
    } else if (candidate != null && !_stopped) {
      _server.attach(candidate);
    } else {
      await candidate?.close(force: true);
    }
    _lastError = null;
    return next;
  });

  Future<LocalApiSettings> resetToken() => _commands.run(() async {
    _requireAvailable();
    final current = await _load();
    final next = LocalApiSettings(
      enabled: current.enabled,
      port: current.port,
      token: _newToken(),
    );
    await _writeSettings(next.toJson());
    _settings = next;
    return next;
  });

  void _requireAvailable() {
    if (!_desktop) throw StateError('Local API is available only on desktop');
    if (_paused || _stopped) {
      throw StateError('Local API settings are unavailable');
    }
  }

  static String _newToken() {
    final random = Random.secure();
    return base64Url
        .encode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  Future<void> pauseForDataClear() async {
    _paused = true;
    await _commands.pause();
    await _server.drained;
  }

  void resumeAfterDataClear() {
    if (!_stopped) _commands.resume();
    _paused = false;
  }

  /// Called only after destructive cleanup has reached preference deletion.
  /// Reset memory too, so resume cannot keep serving the revoked credential.
  Future<void> clearAfterDataClear() async {
    await _server.close();
    _settings = const LocalApiSettings();
    _lastError = null;
  }

  Future<void> stop() async {
    _stopped = true;
    final commands = _commands.pause();
    await _server.close();
    await commands;
    await _server.close();
  }
}
