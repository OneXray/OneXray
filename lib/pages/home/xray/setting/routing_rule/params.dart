import 'package:onexray/service/xray/setting/routing_rule_state.dart';

class RoutingRuleParams {
  final RoutingRuleState state;
  final List<String> outboundTags;

  RoutingRuleParams(this.state, this.outboundTags);
}
