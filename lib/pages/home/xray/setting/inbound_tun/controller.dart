import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/home/xray/setting/inbound_sniffing/params.dart';
import 'package:onexray/pages/home/xray/setting/inbound_tun/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';

class InboundTunCubitState {
  final InboundTunState tunState;
  final int version;

  const InboundTunCubitState({
    required this.tunState,
    this.version = 0,
  });

  factory InboundTunCubitState.initial() => InboundTunCubitState(
        tunState: InboundTunState(),
      );

  InboundTunCubitState bumped() => InboundTunCubitState(
        tunState: tunState,
        version: version + 1,
      );
}

class InboundTunController extends Cubit<InboundTunCubitState> {
  final InboundTunParams params;
  InboundTunController(this.params) : super(InboundTunCubitState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(InboundTunCubitState(tunState: params.state, version: 1));
  }

  Future<void> editSniffing(BuildContext context) async {
    final params = InboundSniffingParams(state.tunState.sniffing);
    final sniffing = await context.push<InboundSniffingState>(
      RouterPath.inboundSniffing,
      extra: params,
    );
    if (sniffing != null) {
      state.tunState.sniffing = sniffing; emit(state.bumped());
    }
  }

  void save(BuildContext context) {
    _mergeInputToState(state.tunState);
    emit(state.bumped());
    context.pop<InboundTunState>(state.tunState);
  }

  void _mergeInputToState(InboundTunState state) {
    state.removeWhitespace();
  }
}
