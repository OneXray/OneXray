import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_query/params.dart';
import 'package:onexray/service/xray/profile/routing_rule_state.dart';

class RoutingRuleDnsQueryPageState {
  final RoutingRuleState ruleState;
  final List<String> outboundTags;
  final int version;

  RoutingRuleDnsQueryPageState({
    required this.ruleState,
    List<String>? outboundTags,
    this.version = 0,
  }) : outboundTags = outboundTags ?? <String>[];

  factory RoutingRuleDnsQueryPageState.initial() =>
      RoutingRuleDnsQueryPageState(ruleState: RoutingRuleState());

  RoutingRuleDnsQueryPageState bumped() => RoutingRuleDnsQueryPageState(
    ruleState: ruleState,
    outboundTags: outboundTags,
    version: version + 1,
  );
}

class RoutingRuleDnsQueryController
    extends Cubit<RoutingRuleDnsQueryPageState> {
  final RoutingRuleDnsQueryParams params;
  RoutingRuleDnsQueryController(this.params)
    : super(RoutingRuleDnsQueryPageState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(
      RoutingRuleDnsQueryPageState(
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
