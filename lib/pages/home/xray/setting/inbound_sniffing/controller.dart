import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/home/xray/setting/inbound_sniffing/params.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';

class InboundSniffingCubitState {
  final InboundSniffingState sniffingState;
  final int version;

  InboundSniffingCubitState({
    required this.sniffingState,
    this.version = 0,
  });

  factory InboundSniffingCubitState.initial() => InboundSniffingCubitState(
        sniffingState: InboundSniffingState(),
      );

  InboundSniffingCubitState bumped() => InboundSniffingCubitState(
        sniffingState: sniffingState,
        version: version + 1,
      );
}

class InboundSniffingController extends Cubit<InboundSniffingCubitState> {
  final InboundSniffingParams params;
  InboundSniffingController(this.params) : super(InboundSniffingCubitState.initial()) {
    _initParams();
  }

  @override
  Future<void> close() {
    for (final controller in domainsExcludedControllers) {
      controller.dispose();
    }
    return super.close();
  }

  void _initParams() {
    final initS = params.state;
    _initInputs(initS);
    emit(InboundSniffingCubitState(sniffingState: initS, version: 1));
  }

  void _initInputs(InboundSniffingState state) {
    final domainsExcludedControllers = state.domainsExcluded.map(
      (e) => TextEditingController(text: e),
    );
    this.domainsExcludedControllers.clear();
    this.domainsExcludedControllers.addAll(domainsExcludedControllers);
  }

  void updateEnabled(bool value) {
    state.sniffingState.enabled = value; emit(state.bumped());
  }

  void updateRouteOnly(bool value) {
    state.sniffingState.routeOnly = value; emit(state.bumped());
  }

  void updateDestOverride(bool selected, InboundSniffingDestOverride value) {
    if (selected) {
        state.sniffingState.destOverride.add(value);
      } else {
        state.sniffingState.destOverride.remove(value);
      }
    emit(state.bumped());
  }

  final domainsExcludedControllers = <TextEditingController>[];

  void appendDomainsExcluded() {
    domainsExcludedControllers.add(TextEditingController());
    state.sniffingState.domainsExcluded.add("");
    emit(state.bumped());
  }

  void deleteDomainsExcluded(BuildContext context, int index) {
    final controller = domainsExcludedControllers.removeAt(index);
    controller.dispose();
    state.sniffingState.domainsExcluded.removeAt(index); emit(state.bumped());
  }

  Future<void> save(BuildContext context) async {
    _mergeInputsToState(state.sniffingState);
    emit(state.bumped());
    if (context.mounted) {
      context.pop<InboundSniffingState>(state.sniffingState);
    }
  }

  void _mergeInputsToState(InboundSniffingState state) {
    state.domainsExcluded = domainsExcludedControllers
        .map((c) => c.text)
        .toList();

    state.removeWhitespace();
  }
}
