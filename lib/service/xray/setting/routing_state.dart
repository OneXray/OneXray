import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/routing_rule_state.dart';
import 'package:onexray/service/xray/setting/state.dart';
import 'package:onexray/service/xray/standard.dart';

class RoutingState {
  var domainStrategy = RoutingDomainStrategy.ipIfNonMatch;
  var dnsQueryRule = RoutingRuleState.dnsQueryRule;
  final dnsOutRule = RoutingRuleState.dnsOutRule;
  var dnsDoTRule = RoutingRuleState.dnsDoTRule;
  final pingRule = RoutingRuleState.pingRule;
  var customRules = <RoutingRuleState>[];

  void removeWhitespace() {
    for (final rule in customRules) {
      rule.removeWhitespace();
    }
  }

  void readFromXrayJson(XrayJson xrayJson) {
    if (xrayJson.routing == null) {
      return;
    }
    final routing = xrayJson.routing!;
    if (EmptyTool.checkString(routing.domainStrategy)) {
      final domainStrategy = RoutingDomainStrategy.fromString(
        routing.domainStrategy!,
      );
      if (domainStrategy != null) {
        this.domainStrategy = domainStrategy;
      }
    }
    if (EmptyTool.checkList(routing.rules)) {
      for (final rule in routing.rules!) {
        final ruleState = RoutingRuleState();
        if (EmptyTool.checkString(rule.ruleTag)) {
          if (rule.ruleTag! == RoutingRuleTag.dnsQuery) {
            ruleState.readFromRoutingRule(rule);
            dnsQueryRule.outboundTag = ruleState.outboundTag;
          } else if (rule.ruleTag! == RoutingRuleTag.dnsOut) {
            continue;
          } else if (rule.ruleTag! == RoutingRuleTag.dnsDoT) {
            ruleState.readFromRoutingRule(rule);
            dnsDoTRule.outboundTag = ruleState.outboundTag;
          } else if (rule.ruleTag! == RoutingRuleTag.ping) {
            continue;
          } else {
            ruleState.readFromRoutingRule(rule);
            customRules.add(ruleState);
          }
        } else {
          ruleState.readFromRoutingRule(rule);
          customRules.add(ruleState);
        }
      }
    }
  }

  XrayRouting get xrayJson {
    final routing = XrayRoutingStandard.standard;
    routing.domainStrategy = domainStrategy.name;
    final rules = <RoutingRuleState>[
      dnsQueryRule,
      dnsOutRule,
      dnsDoTRule,
      pingRule,
    ];
    if (customRules.isNotEmpty) {
      rules.addAll(customRules);
    }
    routing.rules = rules.map((e) => e.xrayJson).toList();
    return routing;
  }
}
