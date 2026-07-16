import 'dart:async';

import 'package:duration/duration.dart';
import 'package:duration/locale.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/pigeon/model_reader.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/metrics/service.dart';

final class VpnConnectivityService {
  final bool Function() _isRunning;

  VpnConnectivityService(this._isRunning);

  Timer? _durationTimer;
  var _startTime = DateTime.now();
  var _testGeneration = 0;

  Future<void> start() async {
    stop();
    _startTime = await PreferencesKey().readVpnStartTimestamp();
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateDuration(),
    );
    await _startMetrics();
    await _runConnectivityTest();
  }

  void stop() {
    _testGeneration++;
    _durationTimer?.cancel();
    _durationTimer = null;
    XrayMetricsService().stop();
    AppEventBus.instance.resetConnectivityProbe();
  }

  Future<void> retry() {
    if (!_isRunning()) {
      AppEventBus.instance.resetConnectivityProbe();
      return Future.value();
    }
    return _runConnectivityTest(initialDelay: Duration.zero);
  }

  Future<void> _runConnectivityTest({
    Duration initialDelay = const Duration(seconds: 3),
  }) async {
    final eventBus = AppEventBus.instance;
    if (!_isRunning()) {
      eventBus.resetConnectivityProbe();
      return;
    }
    final generation = ++_testGeneration;
    eventBus.startConnectivityProbe();

    StartVpnRequest request;
    try {
      request = await StartVpnRequestReader.readFromStartFile();
    } catch (error, stackTrace) {
      ygLogger(
        'read connectivity runtime snapshot failed: $error\n$stackTrace',
      );
      eventBus.updateLocationPingFailed();
      eventBus.updateGeoLocationFailed();
      return;
    }

    final pingPort = request.pingPort;
    if (pingPort == null) {
      eventBus.updateLocationPingFailed();
      eventBus.updateGeoLocationFailed();
      return;
    }

    if (initialDelay > Duration.zero) {
      await Future.delayed(initialDelay);
    }
    if (!_isCurrent(generation)) {
      return;
    }

    final pingState = PingState();
    await pingState.readFromPreferences();
    await Future.wait([
      _runPingProbe(generation, pingPort, pingState.realUrl, request.pingAuth),
      _runGeoLocationProbe(generation, pingPort, request.pingAuth),
    ]);
  }

  bool _isCurrent(int generation) {
    return generation == _testGeneration && _isRunning();
  }

  Future<void> _runPingProbe(
    int generation,
    String port,
    String url,
    XrayInboundAccount? auth,
  ) async {
    final delay = await NetClient().ping(port, url, auth);
    if (!_isCurrent(generation)) {
      return;
    }
    if (delay == null) {
      AppEventBus.instance.updateLocationPingFailed();
      return;
    }
    AppEventBus.instance.updateLocationDelay(delay);
  }

  Future<void> _runGeoLocationProbe(
    int generation,
    String port,
    XrayInboundAccount? auth,
  ) async {
    final location = await NetClient().geoLocation(port, auth);
    if (!_isCurrent(generation)) {
      return;
    }
    if (location == null) {
      AppEventBus.instance.updateGeoLocationFailed();
      return;
    }
    AppEventBus.instance.updateGeoLocation(location);
  }

  Future<void> _startMetrics() async {
    try {
      final request = await StartVpnRequestReader.readFromStartFile();
      XrayMetricsService().start(request.metricsPort);
    } catch (error, stackTrace) {
      ygLogger('read metrics runtime snapshot failed: $error\n$stackTrace');
      XrayMetricsService().stop();
    }
  }

  void _updateDuration() {
    final duration = DateTime.now().difference(_startTime);
    final languageCode =
        AppEventBus.instance.state.languageCode.locale.languageCode;
    final locale =
        DurationLocale.fromLanguageCode(languageCode) ??
        EnglishDurationLocale();
    AppEventBus.instance.updateLocationDuration(
      _formatDuration(duration, locale),
    );
  }

  String _formatDuration(Duration duration, DurationLocale locale) {
    if (duration.inHours >= 1) {
      return duration.pretty(
        locale: locale,
        tersity: DurationTersity.hour,
        upperTersity: DurationTersity.hour,
      );
    }
    if (duration.inMinutes >= 1) {
      return duration.pretty(
        locale: locale,
        tersity: DurationTersity.minute,
        upperTersity: DurationTersity.minute,
      );
    }
    return duration.pretty(
      locale: locale,
      tersity: DurationTersity.second,
      upperTersity: DurationTersity.second,
    );
  }
}
