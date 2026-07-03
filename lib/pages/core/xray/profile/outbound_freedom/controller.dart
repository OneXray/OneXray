import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/outbound_freedom/params.dart';
import 'package:onexray/pages/core/tun/network_interface/params.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';
import 'package:onexray/pages/main/navigation.dart';

class OutboundFreedomPageState {
  final OutboundFreedomState freedomState;
  final int version;

  const OutboundFreedomPageState({
    required this.freedomState,
    this.version = 0,
  });

  factory OutboundFreedomPageState.initial() =>
      OutboundFreedomPageState(freedomState: OutboundFreedomState());

  OutboundFreedomPageState bumped() => OutboundFreedomPageState(
    freedomState: freedomState,
    version: version + 1,
  );
}

class OutboundFreedomController extends Cubit<OutboundFreedomPageState> {
  final OutboundFreedomParams params;
  OutboundFreedomController(this.params)
    : super(OutboundFreedomPageState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(OutboundFreedomPageState(freedomState: params.state, version: 1));
  }

  Future<void> editInterface(BuildContext context) async {
    final params = NetworkInterfaceParams(state.freedomState.interface);
    final networkInterface = await context.pushScoped<String>(
      AppSecondaryDestination.networkInterface,
      extra: params,
    );
    if (networkInterface != null) {
      state.freedomState.interface = networkInterface;
      emit(state.bumped());
    }
  }

  void save(BuildContext context) {
    _mergeInputToState(state.freedomState);
    emit(state.bumped());
    context.pop<OutboundFreedomState>(state.freedomState);
  }

  void _mergeInputToState(OutboundFreedomState state) {
    state.removeWhitespace();
  }
}
