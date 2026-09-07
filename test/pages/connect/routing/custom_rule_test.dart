import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/connect/routing/custom/rule_controller.dart';
import 'package:onexray/service/connect/routing/custom/geodata_suggestions.dart';
import 'package:onexray/service/connect/routing/custom/state.dart';

void main() {
  test(
    'four-condition editor cleans entries and emits only native rule fields',
    () {
      final original = RoutingRuleState(
        ruleTag: 'Original',
        domain: const ['old.example'],
      );
      final controller = CustomRoutingRuleController(rule: original);
      addTearDown(controller.close);
      controller.name.text = ' Renamed ';
      controller.domains.single.text.text = ' geosite:CN ';
      controller.addValue(true);
      controller.ips.single.text.text = ' 10.0.0.0/8 ';
      controller.port.text = '443,1000-2000';
      controller.setNetwork('udp');
      controller.setAction(RoutingRuleAction.direct);
      expect(controller.draftRule.toJson(), {
        'ruleTag': 'Renamed',
        'domain': ['geosite:CN'],
        'ip': ['10.0.0.0/8'],
        'port': '443,1000-2000',
        'network': 'udp',
        'outboundTag': 'direct',
      });
      expect(original.ruleTag, 'Original');
      expect(original.domain, ['old.example']);
      controller.port.text = '65536';
      expect(controller.draftRule.port, '65536');
    },
  );

  test(
    'incomplete drafts remain editable until the full profile is validated',
    () {
      final empty = CustomRoutingRuleController();
      addTearDown(empty.close);
      expect(empty.draftRule.toJson(), {'balancerTag': 'proxy'});
      final both = CustomRoutingRuleController(
        rule: RoutingRuleState(
          network: const ['tcp', 'udp'],
          action: RoutingRuleAction.block,
        ),
      );
      addTearDown(both.close);
      expect(both.draftRule.network, ['tcp', 'udp']);
      final duplicate = CustomRoutingRuleController(
        rule: RoutingRuleState(
          network: const ['tcp', 'tcp'],
          port: 443,
          action: RoutingRuleAction.direct,
        ),
      );
      addTearDown(duplicate.close);
      expect(duplicate.state.network, 'tcp');
      expect(duplicate.draftRule.port, 443);
    },
  );

  test('unvalidated network values remain in the draft without crashing the editor', () {
    for (final network in [
      <String, dynamic>{'unknown': true},
      [1],
      'future-network',
    ]) {
      final controller = CustomRoutingRuleController(
        rule: RoutingRuleState(network: network),
      );
      addTearDown(controller.close);
      expect(controller.draftRule.network, network);
    }
  });

  test('autocomplete separates installed domain and IP references and uses fresh indexes', () async {
    var index = const RoutingGeodataIndex(
      domainFiles: {
        'geosite.dat': ['CN'],
        'other.dat': ['CN'],
      },
      ipFiles: {
        'geoip.dat': ['cn'],
        'local-ip.dat': ['private'],
      },
    );
    final controller = CustomRoutingRuleController(
      loadIndex: () async => index,
    );
    addTearDown(controller.close);
    expect(await controller.suggestions('cn', true), [
      'ext:other.dat:CN',
      'geosite:CN',
    ]);
    expect(await controller.suggestions('cn', false), ['geoip:cn']);
    index = const RoutingGeodataIndex(domainFiles: {}, ipFiles: {});
    expect(await controller.suggestions('cn', true), isEmpty);
  });
}
