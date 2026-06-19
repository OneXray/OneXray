import 'package:onexray/service/xray/metrics/state.dart';

abstract final class XrayMetricsFormatter {
  static String formatTraffic(TrafficMetricsState metrics) {
    if (!metrics.available) {
      return "↑ --   ↓ --";
    }
    return "↑ ${formatSpeed(metrics.uploadSpeed)}   ↓ ${formatSpeed(metrics.downloadSpeed)}";
  }

  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) {
      return "0 KB/s";
    }
    final kb = bytesPerSecond / 1000;
    if (kb < 1000) {
      return "${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB/s";
    }
    final mb = kb / 1000;
    return "${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB/s";
  }
}
