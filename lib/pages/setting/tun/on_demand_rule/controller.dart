import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/setting/tun/on_demand_rule/params.dart';
import 'package:onexray/service/tun_setting/enum.dart';
import 'package:onexray/service/tun_setting/state.dart';
import 'package:onexray/service/tun_setting/state_validator.dart';

class OnDemandRulePageState {
  final OnDemandRuleState ruleState;
  final List<String> ssids;

  OnDemandRulePageState({
    OnDemandRuleState? ruleState,
    this.ssids = const [],
  }) : ruleState = ruleState ?? OnDemandRuleState();

  OnDemandRulePageState _copy() {
    return OnDemandRulePageState(
      ruleState: ruleState,
      ssids: List.from(ssids),
    );
  }
}

class OnDemandRuleController extends Cubit<OnDemandRulePageState> {
  final OnDemandRuleParams params;

  OnDemandRuleController(this.params) : super(OnDemandRulePageState()) {
    _initParams();
  }

  final ssidControllers = <TextEditingController>[];

  @override
  Future<void> close() {
    for (final controller in ssidControllers) {
      controller.dispose();
    }
    return super.close();
  }

  void _initParams() {
    final ruleState = params.state;
    final ssids = ruleState.ssid.toList();

    final controllers = ssids.map(
      (e) => TextEditingController(text: e),
    );
    ssidControllers.clear();
    ssidControllers.addAll(controllers);

    emit(OnDemandRulePageState(ruleState: ruleState, ssids: ssids));
  }

  void updateMode(String value) {
    final mode = OnDemandRuleMode.fromString(value);
    if (mode != null) {
      state.ruleState.mode = mode;
      emit(state._copy());
    }
  }

  void updateInterfaceType(String value) {
    final interfaceType = OnDemandRuleInterfaceType.fromString(value);
    if (interfaceType != null) {
      state.ruleState.interfaceType = interfaceType;
      emit(state._copy());
    }
  }

  void appendSsid() {
    ssidControllers.add(TextEditingController());
    final newSsids = List<String>.from(state.ssids)..add("");
    emit(OnDemandRulePageState(ruleState: state.ruleState, ssids: newSsids));
  }

  void deleteSsid(BuildContext context, int index) {
    final controller = ssidControllers.removeAt(index);
    controller.dispose();
    final newSsids = List<String>.from(state.ssids)..removeAt(index);
    emit(OnDemandRulePageState(ruleState: state.ruleState, ssids: newSsids));
  }

  void save(BuildContext context) {
    _mergeInputToState(state.ruleState);
    context.pop<OnDemandRuleState>(state.ruleState);
  }

  void _mergeInputToState(OnDemandRuleState ruleState) {
    _mergeInputs(ruleState);
    ruleState.removeWhitespace();
  }

  void _mergeInputs(OnDemandRuleState ruleState) {
    ruleState.ssid = ssidControllers.map((c) => c.text).toSet();
  }
}
