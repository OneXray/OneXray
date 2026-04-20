import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_out/params.dart';
import 'package:onexray/service/xray/setting/routing_rule_state.dart';

class RoutingRuleDnsOutCubitState {
  final RoutingRuleState ruleState;
  final int version;

  const RoutingRuleDnsOutCubitState({
    required this.ruleState,
    this.version = 0,
  });

  factory RoutingRuleDnsOutCubitState.initial() => RoutingRuleDnsOutCubitState(
        ruleState: RoutingRuleState(),
      );

  RoutingRuleDnsOutCubitState bumped() => RoutingRuleDnsOutCubitState(
        ruleState: ruleState,
        version: version + 1,
      );
}

class RoutingRuleDnsOutController extends Cubit<RoutingRuleDnsOutCubitState> {
  final RoutingRuleDnsOutParams params;
  RoutingRuleDnsOutController(this.params) : super(RoutingRuleDnsOutCubitState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(RoutingRuleDnsOutCubitState(ruleState: params.state, version: 1));
  }
}
