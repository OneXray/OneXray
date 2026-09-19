import 'package:onexray/core/tools/traffic_format.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/connect/coordinator.dart';

({String title, String tooltip}) trayTrafficText(
  ConnectionView view,
  AppLocalizations l,
) {
  if (view.phase != ConnectionPhase.connected) {
    return (title: '', tooltip: 'OneXray');
  }
  String bytes(int value) => formatTraffic(value, connection: true);
  final speed = view.metricsAvailable
      ? '↓ ${bytes(view.downloadSpeed)}/s  ↑ ${bytes(view.uploadSpeed)}/s'
      : '↓ —  ↑ —';
  final traffic = view.traffic;
  final download = traffic == null ? '—' : bytes(traffic.downlink);
  final upload = traffic == null ? '—' : bytes(traffic.uplink);
  return (
    title: speed,
    tooltip:
        'OneXray · ${l.prototypeThisConnection}\n'
        '${l.prototypeDownload}: $download\n'
        '${l.prototypeUpload}: $upload\n'
        '${l.prototypeCurrentSpeed}: $speed',
  );
}
