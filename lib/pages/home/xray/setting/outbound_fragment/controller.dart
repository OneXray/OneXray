import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/home/xray/setting/outbound_fragment/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/setting/tun/network_interface/params.dart';
import 'package:onexray/service/xray/setting/outbounds_state.dart';

class OutboundFragmentCubitState {
  final OutboundFragmentState fragmentState;
  final int version;

  const OutboundFragmentCubitState({
    required this.fragmentState,
    this.version = 0,
  });

  factory OutboundFragmentCubitState.initial() => OutboundFragmentCubitState(
        fragmentState: OutboundFragmentState(),
      );

  OutboundFragmentCubitState bumped() => OutboundFragmentCubitState(
        fragmentState: fragmentState,
        version: version + 1,
      );
}

class OutboundFragmentController extends Cubit<OutboundFragmentCubitState> {
  final OutboundFragmentParams params;
  OutboundFragmentController(this.params) : super(OutboundFragmentCubitState.initial()) {
    _initParams();
  }

  @override
  Future<void> close() {
    packetsController.dispose();
    lengthController.dispose();
    intervalController.dispose();
    return super.close();
  }

  void _initParams() {
    emit(OutboundFragmentCubitState(fragmentState: params.state, version: 1));
  }

  final packetsController = TextEditingController();
  final lengthController = TextEditingController();
  final intervalController = TextEditingController();

  Future<void> editInterface(BuildContext context) async {
    final params = NetworkInterfaceParams(state.fragmentState.interface);
    final networkInterface = await context.push<String>(
      RouterPath.networkInterface,
      extra: params,
    );
    if (networkInterface != null) {
      state.fragmentState.interface = networkInterface; emit(state.bumped());
    }
  }

  void save(BuildContext context) {
    _mergeInputToState(state.fragmentState);
    emit(state.bumped());
    context.pop<OutboundFragmentState>(state.fragmentState);
  }

  void _mergeInputToState(OutboundFragmentState state) {
    state.packets = packetsController.text;
    state.length = lengthController.text;
    state.interval = intervalController.text;

    state.removeWhitespace();
  }
}
