import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/home/xray/setting/routing_rule_dns_dot/params.dart';
import 'package:onexray/service/xray/setting/routing_rule_state.dart';

class RoutingRuleDnsDoTCubitState {
  final RoutingRuleState ruleState;
  final outboundTags = <String>[];
  final int version;

  RoutingRuleDnsDoTCubitState({
    required this.ruleState,
    this.version = 0,
  });

  factory RoutingRuleDnsDoTCubitState.initial() => RoutingRuleDnsDoTCubitState(
        ruleState: RoutingRuleState(),
      );

  RoutingRuleDnsDoTCubitState bumped() => RoutingRuleDnsDoTCubitState(
        ruleState: ruleState,
        version: version + 1,
      );
}

class RoutingRuleDnsDoTController extends Cubit<RoutingRuleDnsDoTCubitState> {
  final RoutingRuleDnsDoTParams params;
  RoutingRuleDnsDoTController(this.params) : super(RoutingRuleDnsDoTCubitState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(RoutingRuleDnsDoTCubitState(ruleState: params.state, version: 1));
  }

  void updateOutboundTag(String value) {
    state.ruleState.outboundTag = value; emit(state.bumped());
  }

  void save(BuildContext context) {
    context.pop<RoutingRuleState>(state.ruleState);
  }
}
