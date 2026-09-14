import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/connect/routing/dns.dart';

void main() {
  test('only unconditional direct domain rules contribute to local DNS', () {
    final extraConditions = <XrayRoutingRule>[
      XrayRoutingRule(ip: ['192.0.2.0/24']),
      XrayRoutingRule(port: '443'),
      XrayRoutingRule(network: 'tcp'),
      XrayRoutingRule(protocol: ['http']),
      XrayRoutingRule(localOS: ['darwin']),
      XrayRoutingRule(inboundTag: ['tunIn']),
    ];
    for (final rule in extraConditions) {
      rule.domain = ['domain:conditional.test'];
      rule.outboundTag = 'direct';
    }
    expect(
      RoutingDns.directDomains([
        XrayRoutingRule(domain: ['domain:proxy.test'], balancerTag: 'proxy'),
        XrayRoutingRule(domain: ['domain:block.test'], outboundTag: 'block'),
        ...extraConditions,
        XrayRoutingRule(
          domain: ['domain:direct.test', 'geosite:cn'],
          outboundTag: 'direct',
        ),
        XrayRoutingRule(domain: ['domain:direct.test'], outboundTag: 'direct'),
      ]),
      ['domain:direct.test', 'geosite:cn'],
    );
    for (final rule in extraConditions) {
      expect(rule.domain, ['domain:conditional.test']);
      expect(rule.outboundTag, 'direct');
    }
  });
}
