import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/routing/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_dot/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_out/params.dart';
import 'package:onexray/pages/core/xray/profile/routing_rule_dns_query/params.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/routing_rule_state.dart';
import 'package:onexray/service/xray/profile/routing_state.dart';
import 'package:onexray/pages/main/navigation.dart';

class RoutingPageState {
  final RoutingState routingState;
  final int version;

  RoutingPageState({required this.routingState, this.version = 0});

  factory RoutingPageState.initial() =>
      RoutingPageState(routingState: RoutingState());

  RoutingPageState bumped() =>
      RoutingPageState(routingState: routingState, version: version + 1);
}

class RoutingController extends Cubit<RoutingPageState> {
  final RoutingParams params;
  RoutingController(this.params) : super(RoutingPageState.initial()) {
    _initParams();
  }
  final outboundTags = <String>[];
  final inboundTags = <String>[];

  void _initParams() {
    outboundTags.clear();
    outboundTags.addAll(params.outboundTags);
    inboundTags.clear();
    inboundTags.addAll(params.inboundTags);
    emit(RoutingPageState(routingState: params.state, version: 1));
  }

  void updateDomainStrategy(String value) {
    final domainStrategy = RoutingDomainStrategy.fromString(value);
    if (domainStrategy != null) {
      state.routingState.domainStrategy = domainStrategy;
      emit(state.bumped());
    }
  }

  Future<void> showSystemRule(BuildContext context, int index) async {
    switch (index) {
      case 0:
        await _showDnsQueryRule(context);
        break;
      case 1:
        _showDnsOutRule(context);
        break;
      case 2:
        await _showDnsDoTRule(context);
        break;
      default:
        break;
    }
  }

  Future<void> _showDnsQueryRule(BuildContext context) async {
    final dnsOutboundTags = outboundTags
        .where((e) => e.isNotEmpty && e != RoutingOutboundTag.block.name)
        .toList();
    final params = RoutingRuleDnsQueryParams(
      state.routingState.dnsQueryRule,
      dnsOutboundTags,
    );

    final rule = await context.pushScoped<RoutingRuleState>(
      AppSecondaryDestination.routingRuleDnsQuery,
      extra: params,
    );
    if (rule != null) {
      state.routingState.dnsQueryRule = rule;
      emit(state.bumped());
    }
  }

  void _showDnsOutRule(BuildContext context) {
    final params = RoutingRuleDnsOutParams(state.routingState.dnsOutRule);
    context.pushScoped(
      AppSecondaryDestination.routingRuleDnsOut,
      extra: params,
    );
  }

  Future<void> _showDnsDoTRule(BuildContext context) async {
    final dnsOutboundTags = outboundTags
        .where((e) => e.isNotEmpty && e != RoutingOutboundTag.block.name)
        .toList();
    final params = RoutingRuleDnsDoTParams(
      state.routingState.dnsDoTRule,
      dnsOutboundTags,
    );
    final rule = await context.pushScoped<RoutingRuleState>(
      AppSecondaryDestination.routingRuleDnsDot,
      extra: params,
    );
    if (rule != null) {
      state.routingState.dnsDoTRule = rule;
      emit(state.bumped());
    }
  }

  void appendCustomRule() {
    state.routingState.customRules.add(RoutingRuleState());
    emit(state.bumped());
  }

  void sortCustomRule(int oldIndex, int newIndex) {
    final rules = state.routingState.customRules;
    final rule = rules.removeAt(oldIndex);
    var index = newIndex;
    if (newIndex > oldIndex) {
      index = newIndex - 1;
    }
    rules.insert(index, rule);
    state.routingState.customRules = rules;
    emit(state.bumped());
  }

  Future<void> editCustomRule(BuildContext context, int index) async {
    final params = RoutingRuleParams(
      state.routingState.customRules[index],
      outboundTags,
      inboundTags,
    );
    final rule = await context.pushScoped<RoutingRuleState>(
      AppSecondaryDestination.routingRule,
      extra: params,
    );
    if (rule != null) {
      state.routingState.customRules[index] = rule;
      emit(state.bumped());
    }
  }

  void ruleMoreAction(IconMenuId menuId, int ruleIndex) async {
    state.routingState.customRules.removeAt(ruleIndex);
    emit(state.bumped());
  }

  Future<void> save(BuildContext context) async {
    context.pop<RoutingState>(state.routingState);
  }
}
