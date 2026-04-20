import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/home/xray/setting/outbound_freedom/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/setting/tun/network_interface/params.dart';
import 'package:onexray/service/xray/setting/outbounds_state.dart';

class OutboundFreedomCubitState {
  final OutboundFreedomState freedomState;
  final int version;

  const OutboundFreedomCubitState({
    required this.freedomState,
    this.version = 0,
  });

  factory OutboundFreedomCubitState.initial() => OutboundFreedomCubitState(
        freedomState: OutboundFreedomState(),
      );

  OutboundFreedomCubitState bumped() => OutboundFreedomCubitState(
        freedomState: freedomState,
        version: version + 1,
      );
}

class OutboundFreedomController extends Cubit<OutboundFreedomCubitState> {
  final OutboundFreedomParams params;
  OutboundFreedomController(this.params) : super(OutboundFreedomCubitState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(OutboundFreedomCubitState(freedomState: params.state, version: 1));
  }

  Future<void> editInterface(BuildContext context) async {
    final params = NetworkInterfaceParams(state.freedomState.interface);
    final networkInterface = await context.push<String>(
      RouterPath.networkInterface,
      extra: params,
    );
    if (networkInterface != null) {
      state.freedomState.interface = networkInterface; emit(state.bumped());
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
