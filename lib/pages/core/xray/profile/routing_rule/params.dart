import 'package:onexray/service/xray/profile/routing_rule_state.dart';

class RoutingRuleParams {
  final RoutingRuleState state;
  final List<String> outboundTags;
  final List<String> inboundTags;

  RoutingRuleParams(this.state, this.outboundTags, this.inboundTags);
}
