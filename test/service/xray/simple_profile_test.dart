import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/service/xray/profile/simple_state_writer.dart';
import 'package:onexray/service/xray/profile/state.dart';

void main() {
  test('Simple Profile emits the ad blocking rule only when enabled', () {
    final simple = XrayProfileSimple();
    expect(
      simple.xrayProfileState.routing.customRules
          .where((rule) => rule.ruleTag == RoutingRuleTag.adBlock)
          .isEmpty,
      isTrue,
    );

    simple.routing.blockAds = true;
    final rules = simple.xrayProfileState.routing.customRules.where(
      (rule) => rule.ruleTag == RoutingRuleTag.adBlock,
    );
    expect(rules, hasLength(1));
    expect(rules.single.domain, ['geosite:CATEGORY-ADS-ALL']);
    expect(rules.single.outboundTag, RoutingOutboundTag.block.name);
  });
}
