import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/inbound_sniffing/params.dart';
import 'package:onexray/pages/core/xray/profile/inbound_tun/params.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/tun_route.dart';
import 'package:onexray/pages/main/navigation.dart';

class InboundTunPageState {
  final InboundTunState tunState;
  final int version;

  const InboundTunPageState({required this.tunState, this.version = 0});

  factory InboundTunPageState.initial() =>
      InboundTunPageState(tunState: InboundTunState());

  InboundTunPageState bumped() =>
      InboundTunPageState(tunState: tunState, version: version + 1);
}

class InboundTunController extends Cubit<InboundTunPageState> {
  final InboundTunParams params;
  InboundTunController(this.params) : super(InboundTunPageState.initial()) {
    _initParams();
  }

  Future<void> _initParams() async {
    final tunState = params.state;
    final tunSettingsState = TunSettingsState();
    await tunSettingsState.readFromPreferences();
    final config = XrayTunRouteConfig.fromTunSetting(tunSettingsState);
    tunState.settings.applyRouteConfig(config);
    emit(InboundTunPageState(tunState: tunState, version: 1));
  }

  Future<void> editSniffing(BuildContext context) async {
    final params = InboundSniffingParams(state.tunState.sniffing);
    final sniffing = await context.pushScoped<InboundSniffingState>(
      AppSecondaryDestination.inboundSniffing,
      extra: params,
    );
    if (sniffing != null) {
      state.tunState.sniffing = sniffing;
      emit(state.bumped());
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
