import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_out/params.dart';
import 'package:onexray/service/xray/profile/routing_rule_state.dart';

class RoutingRuleDnsOutPageState {
  final RoutingRuleState ruleState;
  final int version;

  const RoutingRuleDnsOutPageState({required this.ruleState, this.version = 0});

  factory RoutingRuleDnsOutPageState.initial() =>
      RoutingRuleDnsOutPageState(ruleState: RoutingRuleState());

  RoutingRuleDnsOutPageState bumped() =>
      RoutingRuleDnsOutPageState(ruleState: ruleState, version: version + 1);
}

class RoutingRuleDnsOutController
    extends PageCubit<RoutingRuleDnsOutPageState> {
  final RoutingRuleDnsOutParams params;
  RoutingRuleDnsOutController(this.params)
    : super(RoutingRuleDnsOutPageState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(RoutingRuleDnsOutPageState(ruleState: params.state, version: 1));
  }
}
