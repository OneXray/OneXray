import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/setting/routing_rule_dns_query/params.dart';
import 'package:onexray/service/xray/setting/routing_rule_state.dart';

class RoutingRuleDnsQueryCubitState {
  final RoutingRuleState ruleState;
  final List<String> outboundTags;
  final int version;

  RoutingRuleDnsQueryCubitState({
    required this.ruleState,
    List<String>? outboundTags,
    this.version = 0,
  }) : outboundTags = outboundTags ?? <String>[];

  factory RoutingRuleDnsQueryCubitState.initial() =>
      RoutingRuleDnsQueryCubitState(ruleState: RoutingRuleState());

  RoutingRuleDnsQueryCubitState bumped() => RoutingRuleDnsQueryCubitState(
    ruleState: ruleState,
    outboundTags: outboundTags,
    version: version + 1,
  );
}

class RoutingRuleDnsQueryController
    extends Cubit<RoutingRuleDnsQueryCubitState> {
  final RoutingRuleDnsQueryParams params;
  RoutingRuleDnsQueryController(this.params)
    : super(RoutingRuleDnsQueryCubitState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(
      RoutingRuleDnsQueryCubitState(
        ruleState: params.state,
        outboundTags: List.of(params.outboundTags),
        version: 1,
      ),
    );
  }

  void updateOutboundTag(String value) {
    state.ruleState.outboundTag = value;
    emit(state.bumped());
  }

  void save(BuildContext context) {
    context.pop<RoutingRuleState>(state.ruleState);
  }
}
