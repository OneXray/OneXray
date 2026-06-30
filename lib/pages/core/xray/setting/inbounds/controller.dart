import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/pages/core/xray/setting/inbound_http/params.dart';
import 'package:onexray/pages/core/xray/setting/inbound_ping/params.dart';
import 'package:onexray/pages/core/xray/setting/inbound_socks/params.dart';
import 'package:onexray/pages/core/xray/setting/inbound_tun/params.dart';
import 'package:onexray/pages/core/xray/setting/inbounds/params.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/toast/service.dart';
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

  Future<void> editSocks(BuildContext context) async {
    final params = InboundSocksParams(_inboundsState.socks);
    final socks = await context.pushScoped<InboundSocksState>(
      AppSecondaryDestination.inboundSocks,
      extra: params,
    );
    if (socks != null) {
      _inboundsState.socks = socks;
    }
  }

  Future<void> editHttp(BuildContext context) async {
    final params = InboundHttpParams(_inboundsState.http);
    final http = await context.pushScoped<InboundHttpState>(
      AppSecondaryDestination.inboundHttp,
      extra: params,
    );
    if (http != null) {
      _inboundsState.http = http;
    }
  }

  void save(BuildContext context) {
    _inboundsState.removeWhitespace();
    final socksPort = int.tryParse(_inboundsState.socks.port);
    final httpPort = int.tryParse(_inboundsState.http.port);
    if (!_validPort(socksPort) || !_validPort(httpPort)) {
      ToastService().showToast(
        appLocalizationsNoContext().validationPortInvalid,
      );
      return;
    }
    if (socksPort == httpPort) {
      ToastService().showToast(
        appLocalizationsNoContext().validationPortDuplicate,
      );
      return;
    }
    context.pop<InboundsState>(_inboundsState);
  }

  bool _validPort(int? port) {
    return port != null && port > 0 && port <= 65535;
  }
}
