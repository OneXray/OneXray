import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/xray/metrics/model.dart';

void main() {
  test(
    'current traffic combines tunnel and LAN sharing without user inbounds',
    () {
      final metrics = XrayMetricsVars.fromJson({
        'stats': {
          'inbound': {
            'tunIn': {'uplink': 120, 'downlink': 240},
            'app-lan-proxy': {'uplink': 30, 'downlink': 60},
            'user-http': {'uplink': 1000, 'downlink': 2000},
          },
        },
      });
      expect(metrics.managedTraffic.uplink, 150);
      expect(metrics.managedTraffic.downlink, 300);
      expect(metrics.toJson()['stats']['inbound']['app-lan-proxy'], {
        'uplink': 30,
        'downlink': 60,
      });
    },
  );

  test('LAN-only traffic is counted before tunnel counters are created', () {
    final metrics = XrayMetricsVars.fromJson({
      'stats': {
        'inbound': {
          'app-lan-proxy': {'uplink': 30, 'downlink': 60},
        },
      },
    });
    expect(metrics.managedTraffic.uplink, 30);
    expect(metrics.managedTraffic.downlink, 60);
  });

  test('uncreated counters remain zero', () {
    final metrics = XrayMetricsVars.fromJson({
      'stats': {'inbound': <String, dynamic>{}},
    });
    expect(metrics.managedTraffic.uplink, 0);
    expect(metrics.managedTraffic.downlink, 0);
  });
}
