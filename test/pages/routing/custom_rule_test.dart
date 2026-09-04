import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/pages/routing/custom/rule_controller.dart';
import 'package:onexray/service/routing/geodata_suggestions.dart';

void main() {
  test(
    'four-condition editor cleans entries and emits only native rule fields',
    () {
      final original = <String, dynamic>{
        'ruleTag': 'Original',
        'domain': ['old.example'],
        'balancerTag': 'proxy',
      };
      final controller = CustomRoutingRuleController(rule: original);
      addTearDown(controller.dispose);
      controller.name.text = ' Renamed ';
      controller.domains.single.text.text = ' geosite:CN ';
      controller.addValue(true);
      controller.ips.single.text.text = ' 10.0.0.0/8 ';
      controller.port.text = '443,1000-2000';
      controller.setNetwork('udp');
      controller.setAction('direct');
      expect(controller.buildRule(), {
        'ruleTag': 'Renamed',
        'domain': ['geosite:CN'],
        'ip': ['10.0.0.0/8'],
        'port': '443,1000-2000',
        'network': 'udp',
        'outboundTag': 'direct',
      });
      expect(original['ruleTag'], 'Original');
      expect(original['domain'], ['old.example']);
      controller.port.text = '65536';
      expect(controller.draftRule['port'], '65536');
      expect(controller.buildRule, throwsFormatException);
    },
  );

  test('new empty rule cannot save; explicit tcp/udp condition remains expressible', () {
    final empty = CustomRoutingRuleController();
    addTearDown(empty.dispose);
    expect(empty.buildRule, throwsFormatException);
    final both = CustomRoutingRuleController(
      rule: {
        'network': ['tcp', 'udp'],
        'outboundTag': 'block',
      },
    );
    addTearDown(both.dispose);
    expect(both.buildRule()['network'], ['tcp', 'udp']);
    final duplicate = CustomRoutingRuleController(
      rule: {
        'network': ['tcp', 'tcp'],
        'port': 443,
        'outboundTag': 'direct',
      },
    );
    addTearDown(duplicate.dispose);
    expect(duplicate.network, 'tcp');
    expect(duplicate.buildRule()['port'], 443);
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
    addTearDown(controller.dispose);
    expect(await controller.suggestions('cn', true), [
      'ext:other.dat:CN',
      'geosite:CN',
    ]);
    expect(await controller.suggestions('cn', false), ['geoip:cn']);
    index = const RoutingGeodataIndex(domainFiles: {}, ipFiles: {});
    expect(await controller.suggestions('cn', true), isEmpty);
  });
}
