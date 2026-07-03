import 'package:onexray/pages/core/xray/profile/inbound_ping/params.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InboundPingPageState {
  final InboundPingState httpState;
  final int version;

  const InboundPingPageState({required this.httpState, this.version = 0});

  factory InboundPingPageState.initial() =>
      InboundPingPageState(httpState: InboundPingState());

  InboundPingPageState bumped() =>
      InboundPingPageState(httpState: httpState, version: version + 1);
}

class InboundPingController extends Cubit<InboundPingPageState> {
  final InboundPingParams params;
  InboundPingController(this.params) : super(InboundPingPageState.initial()) {
    _initParams();
  }

  void _initParams() {
    final initS = params.state;
    emit(InboundPingPageState(httpState: initS, version: 1));
  }
}
