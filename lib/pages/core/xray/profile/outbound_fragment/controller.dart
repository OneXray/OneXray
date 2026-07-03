import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/outbound_fragment/params.dart';
import 'package:onexray/pages/core/tun/network_interface/params.dart';
import 'package:onexray/service/xray/profile/outbounds_state.dart';
import 'package:onexray/pages/main/navigation.dart';

class OutboundFragmentPageState {
  final OutboundFragmentState fragmentState;
  final int version;

  const OutboundFragmentPageState({
    required this.fragmentState,
    this.version = 0,
  });

  factory OutboundFragmentPageState.initial() =>
      OutboundFragmentPageState(fragmentState: OutboundFragmentState());

  OutboundFragmentPageState bumped() => OutboundFragmentPageState(
    fragmentState: fragmentState,
    version: version + 1,
  );
}

class OutboundFragmentController extends Cubit<OutboundFragmentPageState> {
  final OutboundFragmentParams params;
  OutboundFragmentController(this.params)
    : super(OutboundFragmentPageState.initial()) {
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
    emit(OutboundFragmentPageState(fragmentState: params.state, version: 1));
  }

  final packetsController = TextEditingController();
  final lengthController = TextEditingController();
  final intervalController = TextEditingController();

  Future<void> editInterface(BuildContext context) async {
    final params = NetworkInterfaceParams(state.fragmentState.interface);
    final networkInterface = await context.pushScoped<String>(
      AppSecondaryDestination.networkInterface,
      extra: params,
    );
    if (networkInterface != null) {
      state.fragmentState.interface = networkInterface;
      emit(state.bumped());
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
