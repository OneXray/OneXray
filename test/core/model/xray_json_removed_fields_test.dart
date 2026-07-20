import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';

void main() {
  test('removed outbound strategy fields are ignored', () {
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
    expect(outbound, isNot(contains('targetStrategy')));

    final streamSettings = outbound['streamSettings'] as Map<String, dynamic>;
    final sockopt = streamSettings['sockopt'] as Map<String, dynamic>;
    expect(sockopt['dialerProxy'], 'chainProxy');
    expect(sockopt, isNot(contains('domainStrategy')));
    expect(sockopt, isNot(contains('addressPortStrategy')));
  });
}
