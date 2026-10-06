import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/shared/xray/metrics/model.dart';

void main() {
  test('current traffic counts only tunnel counters', () {
    final metrics = XrayMetricsVars.fromJson({
      'stats': {
        'inbound': {
          'tunIn': {'uplink': 120, 'downlink': 240},
          'app-lan-proxy': {'uplink': 30, 'downlink': 60},
          'user-http': {'uplink': 1000, 'downlink': 2000},
        },
      },
    });
    expect(metrics.managedTraffic.uplink, 120);
    expect(metrics.managedTraffic.downlink, 240);
    expect(metrics.toJson()['stats']['inbound'], {
      'tunIn': {'uplink': 120, 'downlink': 240},
    });
  });

  test('LAN-only traffic does not contribute to connection traffic', () {
    final metrics = XrayMetricsVars.fromJson({
      'stats': {
        'inbound': {
          'app-lan-proxy': {'uplink': 30, 'downlink': 60},
        },
      },
    });
    expect(metrics.managedTraffic.uplink, 0);
    expect(metrics.managedTraffic.downlink, 0);
  });

  test('uncreated counters remain zero', () {
    final metrics = XrayMetricsVars.fromJson({
      'stats': {'inbound': <String, dynamic>{}},
    });
    expect(metrics.managedTraffic.uplink, 0);
    expect(metrics.managedTraffic.downlink, 0);
  });
}
