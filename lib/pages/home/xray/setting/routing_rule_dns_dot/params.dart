import 'package:onexray/service/xray/setting/routing_rule_state.dart';

class RoutingRuleDnsDoTParams {
  final RoutingRuleState state;
  final List<String> outboundTags;

  RoutingRuleDnsDoTParams(this.state, this.outboundTags);
}
