import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_dot/params.dart';
import 'package:onexray/service/xray/profile/routing_rule_state.dart';

class RoutingRuleDnsDoTPageState {
  final RoutingRuleState ruleState;
  final List<String> outboundTags;
  final int version;

  RoutingRuleDnsDoTPageState({
    required this.ruleState,
    List<String>? outboundTags,
    this.version = 0,
  }) : outboundTags = outboundTags ?? <String>[];

  factory RoutingRuleDnsDoTPageState.initial() =>
      RoutingRuleDnsDoTPageState(ruleState: RoutingRuleState());

  RoutingRuleDnsDoTPageState bumped() => RoutingRuleDnsDoTPageState(
    ruleState: ruleState,
    outboundTags: outboundTags,
    version: version + 1,
  );
}

class RoutingRuleDnsDoTController
    extends PageCubit<RoutingRuleDnsDoTPageState> {
  final RoutingRuleDnsDoTParams params;
  RoutingRuleDnsDoTController(this.params)
    : super(RoutingRuleDnsDoTPageState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(
      RoutingRuleDnsDoTPageState(
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
