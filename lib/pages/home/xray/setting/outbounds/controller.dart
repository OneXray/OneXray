import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/home/xray/setting/outbound_dns/params.dart';
import 'package:onexray/pages/home/xray/setting/outbound_freedom/params.dart';
import 'package:onexray/pages/home/xray/setting/outbound_fragment/params.dart';
import 'package:onexray/pages/home/xray/setting/outbounds/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/outbounds_state.dart';

class OutboundsCubitState {
  final OutboundsState outboundsState;
  final int version;

  const OutboundsCubitState({
    required this.outboundsState,
    this.version = 0,
  });

  factory OutboundsCubitState.initial() => OutboundsCubitState(
        outboundsState: OutboundsState(),
      );

  OutboundsCubitState bumped() => OutboundsCubitState(
        outboundsState: outboundsState,
        version: version + 1,
      );
}

class OutboundsController extends Cubit<OutboundsCubitState> {
  final OutboundsParams params;
  OutboundsController(this.params) : super(OutboundsCubitState.initial()) {
    _initParams();
  }

  void _initParams() {
    emit(OutboundsCubitState(outboundsState: params.state, version: 1));
  }

  Future<void> editFreedom(BuildContext context) async {
    final params = OutboundFreedomParams(state.outboundsState.freedom);
    final freedom = await context.push<OutboundFreedomState>(
      RouterPath.outboundFreedom,
      extra: params,
    );
    if (freedom != null) {
      state.outboundsState.freedom = freedom; emit(state.bumped());
    }
  }

  Future<void> editFragment(BuildContext context) async {
    final params = OutboundFragmentParams(state.outboundsState.fragment);
    final fragment = await context.push<OutboundFragmentState>(
      RouterPath.outboundFragment,
      extra: params,
    );
    if (fragment != null) {
      state.outboundsState.fragment = fragment; emit(state.bumped());
    }
  }

  Future<void> editBlackHole(BuildContext context) async {
    await context.push(RouterPath.outboundBlackHole);
  }

  Future<void> editDns(BuildContext context) async {
    final dnsOutboundTags = state.outboundsState.outboundTags
        .where(
          (e) =>
              e.isNotEmpty &&
              e != RoutingOutboundTag.fragment.name &&
              e != RoutingOutboundTag.block.name,
        )
        .toList();

    final params = OutboundDnsParams(state.outboundsState.dns, dnsOutboundTags);
    final dns = await context.push<OutboundDnsState>(
      RouterPath.outboundDns,
      extra: params,
    );
    if (dns != null) {
      state.outboundsState.dns = dns; emit(state.bumped());
    }
  }

  void save(BuildContext context) {
    context.pop<OutboundsState>(state.outboundsState);
  }
}
