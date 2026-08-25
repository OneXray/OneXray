import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';

void main() {
  test('XrayJson preserves user fields outside the App projection', () {
    final config = XrayJson.fromJson({
      'outbounds': [
        {
          'protocol': 'vless',
          'tag': 'proxy',
          'targetStrategy': 'UseIP',
          'streamSettings': {
            'sockopt': {
              'dialerProxy': 'chainProxy',
              'domainStrategy': 'UseIPv4',
              'addressPortStrategy': 'SrvPortOnly',
            },
          },
        },
      ],
    });

    final outbound = config.toJson()['outbounds']!.first;
    expect(outbound['targetStrategy'], 'UseIP');

    final streamSettings = outbound['streamSettings'] as Map<String, dynamic>;
    final sockopt = streamSettings['sockopt'] as Map<String, dynamic>;
    expect(sockopt['dialerProxy'], 'chainProxy');
    expect(sockopt['domainStrategy'], 'UseIPv4');
    expect(sockopt['addressPortStrategy'], 'SrvPortOnly');
  });
}
