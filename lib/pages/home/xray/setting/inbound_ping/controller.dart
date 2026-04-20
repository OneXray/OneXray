import 'package:onexray/pages/home/xray/setting/inbound_ping/params.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InboundPingCubitState {
  final InboundPingState httpState;
  final int version;

  const InboundPingCubitState({required this.httpState, this.version = 0});

  factory InboundPingCubitState.initial() =>
      InboundPingCubitState(httpState: InboundPingState());

  InboundPingCubitState bumped() =>
      InboundPingCubitState(httpState: httpState, version: version + 1);
}

class InboundPingController extends Cubit<InboundPingCubitState> {
  final InboundPingParams params;
  InboundPingController(this.params) : super(InboundPingCubitState.initial()) {
    _initParams();
  }

  void _initParams() {
    final initS = params.state;
    emit(InboundPingCubitState(httpState: initS, version: 1));
  }
}
