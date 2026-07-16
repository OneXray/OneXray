import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/inbound_sniffing/params.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';

class InboundSniffingPageState {
  final InboundSniffingState sniffingState;
  final int version;

  InboundSniffingPageState({required this.sniffingState, this.version = 0});

  factory InboundSniffingPageState.initial() =>
      InboundSniffingPageState(sniffingState: InboundSniffingState());

  InboundSniffingPageState bumped() => InboundSniffingPageState(
    sniffingState: sniffingState,
    version: version + 1,
  );
}

class InboundSniffingController extends PageCubit<InboundSniffingPageState> {
  final InboundSniffingParams params;
  InboundSniffingController(this.params)
    : super(InboundSniffingPageState.initial()) {
    _initParams();
  }

  @override
  Future<void> disposePageResources() async {
    for (final controller in domainsExcludedControllers) {
      controller.dispose();
    }
    for (final controller in ipsExcludedControllers) {
      controller.dispose();
    }
  }

  void _initParams() {
    final initS = params.state;
    _initInputs(initS);
    emit(InboundSniffingPageState(sniffingState: initS, version: 1));
  }

  void _initInputs(InboundSniffingState state) {
    final domainsExcludedControllers = state.domainsExcluded.map(
      (e) => TextEditingController(text: e),
    );
    this.domainsExcludedControllers.clear();
    this.domainsExcludedControllers.addAll(domainsExcludedControllers);

    final ipsExcludedControllers = state.ipsExcluded.map(
      (e) => TextEditingController(text: e),
    );
    this.ipsExcludedControllers.clear();
    this.ipsExcludedControllers.addAll(ipsExcludedControllers);
  }

  void updateEnabled(bool value) {
    state.sniffingState.enabled = value;
    emit(state.bumped());
  }

  void updateRouteOnly(bool value) {
    state.sniffingState.routeOnly = value;
    emit(state.bumped());
  }

  void updateMetadataOnly(bool value) {
    state.sniffingState.metadataOnly = value;
    emit(state.bumped());
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
    state.sniffingState.domainsExcluded.removeAt(index);
    emit(state.bumped());
  }

  final ipsExcludedControllers = <TextEditingController>[];

  void appendIpsExcluded() {
    ipsExcludedControllers.add(TextEditingController());
    state.sniffingState.ipsExcluded.add("");
    emit(state.bumped());
  }

  void deleteIpsExcluded(BuildContext context, int index) {
    final controller = ipsExcludedControllers.removeAt(index);
    controller.dispose();
    state.sniffingState.ipsExcluded.removeAt(index);
    emit(state.bumped());
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
    state.ipsExcluded = ipsExcludedControllers.map((c) => c.text).toList();

    state.removeWhitespace();
  }
}
