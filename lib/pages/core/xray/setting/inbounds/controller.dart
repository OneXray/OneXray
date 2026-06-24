import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/pages/core/xray/setting/inbound_ping/params.dart';
import 'package:onexray/pages/core/xray/setting/inbound_tun/params.dart';
import 'package:onexray/pages/core/xray/setting/inbounds/params.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/main/navigation.dart';

class InboundsController extends Cubit<int> {
  final InboundsParams params;
  InboundsController(this.params) : super(0) {
    _initParams();
  }

  var _inboundsState = InboundsState();

  void _initParams() {
    _inboundsState = params.state;
  }

  Future<void> editTun(BuildContext context) async {
    final params = InboundTunParams(_inboundsState.tun);
    final tun = await context.pushScoped<InboundTunState>(
      AppSecondaryDestination.inboundTun,
      extra: params,
    );
    if (tun != null) {
      _inboundsState.tun = tun;
    }
  }

  Future<void> editPing(BuildContext context) async {
    final params = InboundPingParams(_inboundsState.ping);
    context.pushScoped<InboundPingState>(
      AppSecondaryDestination.inboundPing,
      extra: params,
    );
  }

  void save(BuildContext context) {
    context.pop<InboundsState>(_inboundsState);
  }
}
