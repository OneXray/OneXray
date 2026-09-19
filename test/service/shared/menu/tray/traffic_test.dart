import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/service/connect/coordinator.dart';
import 'package:onexray/service/connect/traffic.dart';
import 'package:onexray/service/shared/menu/tray/traffic.dart';

void main() {
  final l = AppLocalizationsEn();
  const traffic = ConnectionTraffic(
    uplink: 1024,
    downlink: 4096,
    sampledAtMs: 1,
  );
  test('menu bar shows rates and tooltip shows current session totals', () {
    final text = trayTrafficText(
      const ConnectionView(
        phase: ConnectionPhase.connected,
        traffic: traffic,
        metricsAvailable: true,
        uploadSpeed: 1024,
        downloadSpeed: 1536,
      ),
      l,
    );
    expect(text.title, '↓ 1.5 KB/s  ↑ 1 KB/s');
    expect(
      text.tooltip,
      contains('This connection\nDownload: 4 KB\nUpload: 1 KB'),
    );
  });
  test('metrics failure preserves totals but never displays stale speed', () {
    final text = trayTrafficText(
      const ConnectionView(phase: ConnectionPhase.connected, traffic: traffic),
      l,
    );
    expect(text.title, '↓ —  ↑ —');
    expect(text.tooltip, contains('Download: 4 KB'));
    expect(trayTrafficText(const ConnectionView(), l), (
      title: '',
      tooltip: 'OneXray',
    ));
  });
}
