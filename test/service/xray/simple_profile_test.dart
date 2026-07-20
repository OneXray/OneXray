import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/simple_state_writer.dart';
import 'package:onexray/service/xray/profile/state.dart';

void main() {
  test('Simple Profile emits the ad blocking rule only when enabled', () {
    final simple = XrayProfileSimple();
    expect(
      simple
          .xrayProfileState('8.8.8.8')
          .routing
          .customRules
          .where((rule) => rule.ruleTag == RoutingRuleTag.adBlock)
          .isEmpty,
      isTrue,
    );

    simple.routing.blockAds = true;
    final rules = simple
        .xrayProfileState('8.8.8.8')
        .routing
        .customRules
        .where((rule) => rule.ruleTag == RoutingRuleTag.adBlock);
    expect(rules, hasLength(1));
    expect(rules.single.domain, ['geosite:CATEGORY-ADS-ALL']);
    expect(rules.single.outboundTag, RoutingOutboundTag.block.name);
  });

  test('Simple Profile uses the TUN DNS server over TCP', () {
    final profile = XrayProfileSimple().xrayProfileState('9.9.9.9');
    final server = profile.dns.servers.singleWhere(
      (server) => server.tag == DNSServerTag.defaultDns,
    );

    expect(server.address, 'tcp://9.9.9.9');
  });
}
