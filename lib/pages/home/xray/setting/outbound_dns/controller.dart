import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/params.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/outbounds_state.dart';

class OutboundDnsCubitState {
  final OutboundDnsState dnsState;
  final outboundTags = <String>[];
  final int version;

  OutboundDnsCubitState({
    required this.dnsState,
    this.version = 0,
  });

  factory OutboundDnsCubitState.initial() => OutboundDnsCubitState(
        dnsState: OutboundDnsState(),
      );

  OutboundDnsCubitState bumped() => OutboundDnsCubitState(
        dnsState: dnsState,
        version: version + 1,
      );
}

class OutboundDnsController extends Cubit<OutboundDnsCubitState> {
  final OutboundDnsParams params;
  OutboundDnsController(this.params) : super(OutboundDnsCubitState.initial()) {
    _initParams();
  }

  @override
  Future<void> close() {
    addressController.dispose();
    portController.dispose();
    return super.close();
  }

  void _initParams() {
    final initS = params.state;
    state.outboundTags.clear();
    state.outboundTags.addAll(params.outboundTags);
    _initInput(initS);
    emit(OutboundDnsCubitState(dnsState: initS, version: 1));
  }

  void _initInput(OutboundDnsState state) {
    addressController.text = state.address;
    portController.text = state.port;
  }

  void updateNetwork(String value) {
    final network = DnsNetwork.fromString(value);
    if (network != null) {
      state.dnsState.network = network; emit(state.bumped());
    }
  }

  final addressController = TextEditingController();
  final portController = TextEditingController();

  void updateNonIPQuery(String value) {
    final nonIPQuery = DnsNonIPQuery.fromString(value);
    if (nonIPQuery != null) {
      state.dnsState.nonIPQuery = nonIPQuery; emit(state.bumped());
    }
  }

  void updateDialerProxy(String value) {
    state.dnsState.dialerProxy = value; emit(state.bumped());
  }

  void save(BuildContext context) {
    _mergeInputToState(state.dnsState);
    emit(state.bumped());
    context.pop<OutboundDnsState>(state.dnsState);
  }

  void _mergeInputToState(OutboundDnsState state) {
    _mergeInput(state);

    state.removeWhitespace();
  }

  void _mergeInput(OutboundDnsState state) {
    state.address = addressController.text;
    state.port = portController.text;
  }
}
