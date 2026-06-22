import 'dart:async';
import 'dart:math';

import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/constants.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/metrics/model.dart';
import 'package:onexray/service/xray/metrics/state.dart';

class XrayMetricsService {
  static final XrayMetricsService _singleton = XrayMetricsService._internal();

  factory XrayMetricsService() => _singleton;

  XrayMetricsService._internal();

  static const _pollInterval = Duration(seconds: 1);
  static const _failureBackoffSeconds = [2, 4, 8, 16, 30];

  Timer? _timer;
  var _generation = 0;
  var _querying = false;
  var _consecutiveFailures = 0;
  DateTime? _nextQueryAt;
  int? _lastUploadTotal;
  int? _lastDownloadTotal;
  DateTime? _lastSampleTime;

  void start(String? metricsPort) {
    stop(resetState: false);
    if (metricsPort == null || metricsPort.isEmpty) {
      AppEventBus.instance.resetTrafficMetrics();
      return;
    }
    _generation++;
    final generation = _generation;
    AppEventBus.instance.resetTrafficMetrics();
    unawaited(_query(generation, metricsPort));
    _timer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_query(generation, metricsPort)),
    );
  }

  void stop({bool resetState = true}) {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _querying = false;
    _resetBackoff();
    _resetBaseline();
    if (resetState) {
      AppEventBus.instance.resetTrafficMetrics();
    }
  }

  Future<void> _query(int generation, String metricsPort) async {
    if (_querying || _isBackoffActive()) {
      return;
    }
    _querying = true;
    try {
      final url = "http://${NetConstants.proxyHost}:$metricsPort/debug/vars";
      final payload = await NetClient().getJson(url);
      if (generation != _generation) {
        return;
      }
      final tunIn = payload == null
          ? null
          : XrayMetricsVars.fromJson(payload).tunIn;
      final uploadTotal = tunIn?.uplink;
      final downloadTotal = tunIn?.downlink;
      if (uploadTotal == null || downloadTotal == null) {
        _recordQueryFailure(generation);
        return;
      }

      _resetBackoff();
      final now = DateTime.now();
      final speed = _calculateSpeed(uploadTotal, downloadTotal, now);
      _lastUploadTotal = uploadTotal;
      _lastDownloadTotal = downloadTotal;
      _lastSampleTime = now;

      AppEventBus.instance.updateTrafficMetrics(
        TrafficMetricsState(
          available: true,
          uploadTotal: uploadTotal,
          downloadTotal: downloadTotal,
          uploadSpeed: speed.upload,
          downloadSpeed: speed.download,
        ),
      );
    } catch (e) {
      ygLogger("query metrics failed: $e");
      if (generation == _generation) {
        _recordQueryFailure(generation);
      }
    } finally {
      _querying = false;
    }
  }

  ({int upload, int download}) _calculateSpeed(
    int uploadTotal,
    int downloadTotal,
    DateTime now,
  ) {
    final lastUploadTotal = _lastUploadTotal;
    final lastDownloadTotal = _lastDownloadTotal;
    final lastSampleTime = _lastSampleTime;
    if (lastUploadTotal == null ||
        lastDownloadTotal == null ||
        lastSampleTime == null) {
      return (upload: 0, download: 0);
    }

    final elapsedMs = now.difference(lastSampleTime).inMilliseconds;
    if (elapsedMs <= 0) {
      return (upload: 0, download: 0);
    }
    final uploadBytes = max(0, uploadTotal - lastUploadTotal);
    final downloadBytes = max(0, downloadTotal - lastDownloadTotal);
    return (
      upload: (uploadBytes * 1000 / elapsedMs).round(),
      download: (downloadBytes * 1000 / elapsedMs).round(),
    );
  }

  bool _isBackoffActive() {
    final nextQueryAt = _nextQueryAt;
    return nextQueryAt != null && DateTime.now().isBefore(nextQueryAt);
  }

  void _recordQueryFailure(int generation) {
    if (generation != _generation) {
      return;
    }
    _consecutiveFailures++;
    final seconds =
        _failureBackoffSeconds[min(
          _consecutiveFailures - 1,
          _failureBackoffSeconds.length - 1,
        )];
    _nextQueryAt = DateTime.now().add(Duration(seconds: seconds));
    _resetBaseline();
    AppEventBus.instance.resetTrafficMetrics();
  }

  void _resetBackoff() {
    _consecutiveFailures = 0;
    _nextQueryAt = null;
  }

  void _resetBaseline() {
    _lastUploadTotal = null;
    _lastDownloadTotal = null;
    _lastSampleTime = null;
  }
}
