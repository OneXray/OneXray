import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/xray/constants.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/simple_state_writer.dart';

void main() {
  test('Simple Profile emits the ad blocking rule only when enabled', () {
    final simple = XrayProfileSimple();
    expect(
      _routingRules(simple.xrayProfileMap('8.8.8.8'))
          .where((rule) => rule['ruleTag'] == RoutingRuleTag.adBlock),
      isEmpty,
    );

    simple.routing.blockAds = true;
    final rules = _routingRules(simple.xrayProfileMap('8.8.8.8'))
        .where((rule) => rule['ruleTag'] == RoutingRuleTag.adBlock);
    expect(rules, hasLength(1));
    expect(rules.single['domain'], ['geosite:CATEGORY-ADS-ALL']);
    expect(rules.single['outboundTag'], RoutingOutboundTag.block.name);
  });

  test('Simple Profile uses the TUN DNS server over TCP', () {
    final profile = XrayProfileSimple().xrayProfileMap('9.9.9.9');
    final dns = profile['dns'] as Map<String, dynamic>;
    final servers = (dns['servers'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final server = servers.singleWhere(
      (server) => server['tag'] == DNSServerTag.defaultDns,
    );

    expect(server['address'], 'tcp://9.9.9.9');
  });

  test('Simple Profile preserves the app-managed runtime structure', () {
    final simple = XrayProfileSimple()
      ..enableLog = true
      ..fakeDns = true;
    final profile = simple.xrayProfileMap('9.9.9.9');

    expect(profile, isNot(contains('version')));
    expect(profile, isNot(contains('geodata')));
    expect(profile['fakeDns'], [
      {'ipPool': '198.18.0.0/15', 'poolSize': 32768},
    ]);

    final log = profile['log'] as Map<String, dynamic>;
    expect(log['loglevel'], XrayLogLevel.info.name);
    expect(log['dnsLog'], isTrue);

    final rules = _routingRules(profile);
    expect(rules.take(4).map((rule) => rule['ruleTag']), <String>[
      RoutingRuleTag.dnsQuery,
      RoutingRuleTag.dnsOut,
      RoutingRuleTag.dnsDoT,
      RoutingRuleTag.ping,
    ]);

    final inbounds = (profile['inbounds'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(inbounds.map((inbound) => inbound['tag']), <String>[
      RoutingInboundTag.tunIn.name,
      RoutingInboundTag.pingIn.name,
    ]);
    final sniffing = inbounds.first['sniffing'] as Map<String, dynamic>;
    expect(
      sniffing['destOverride'],
      containsAll(<String>['http', 'tls', 'quic', 'fakedns+others']),
    );

    final outbounds = (profile['outbounds'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(outbounds.map((outbound) => outbound['tag']), <String>[
      RoutingOutboundTag.direct.name,
      RoutingOutboundTag.fragment.name,
      RoutingOutboundTag.block.name,
      RoutingOutboundTag.dnsOut.name,
    ]);
    final streamSettings =
        outbounds.last['streamSettings'] as Map<String, dynamic>;
    final sockopt = streamSettings['sockopt'] as Map<String, dynamic>;
    expect(sockopt['dialerProxy'], RoutingOutboundTag.proxy.name);
  });
}

List<Map<String, dynamic>> _routingRules(Map<String, dynamic> profile) {
  final routing = profile['routing'] as Map<String, dynamic>;
  return (routing['rules'] as List<dynamic>).cast<Map<String, dynamic>>();
}
