import 'package:onexray/pages/home/xray/setting/inbound_ping/params.dart';
import 'package:onexray/pages/home/xray/setting/inbound_tun/params.dart';
import 'package:onexray/pages/home/xray/setting/inbounds/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InboundsController {
  final InboundsParams params;
  InboundsController(this.params) {
    _initParams();
  }

  var _inboundsState = InboundsState();

  void _initParams() {
    _inboundsState = params.state;
  }

  Future<void> editTun(BuildContext context) async {
    final params = InboundTunParams(_inboundsState.tun);
    final tun = await context.push<InboundTunState>(
      RouterPath.inboundTun,
      extra: params,
    );
    if (tun != null) {
      _inboundsState.tun = tun;
    }
  }

  Future<void> editPing(BuildContext context) async {
    final params = InboundPingParams(_inboundsState.ping);
    context.push<InboundPingState>(RouterPath.inboundPing, extra: params);
  }

  void save(BuildContext context) {
    context.pop<InboundsState>(_inboundsState);
  }
}
