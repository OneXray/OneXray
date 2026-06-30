import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/setting/inbound_proxy/params.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';

class InboundProxyCubitState {
  final InboundLocalProxyState proxyState;

  const InboundProxyCubitState({required this.proxyState});

  factory InboundProxyCubitState.initial() => InboundProxyCubitState(
    proxyState: InboundLocalProxyState(
      protocol: XrayInboundProtocol.socks,
      tag: RoutingInboundTag.socksIn,
      defaultPort: "11024",
    ),
  );
}

class InboundProxyController extends Cubit<InboundProxyCubitState> {
  final InboundProxyParams params;

  InboundProxyController(this.params)
    : super(InboundProxyCubitState.initial()) {
    _initParams();
  }

  final portController = TextEditingController();
  final userController = TextEditingController();
  final passController = TextEditingController();

  void _initParams() {
    final state = params.state;
    portController.text = state.port;
    userController.text = state.user;
    passController.text = state.pass;
    emit(InboundProxyCubitState(proxyState: state));
  }

  void save(BuildContext context) {
    final port = portController.text.trim();
    final portValue = int.tryParse(port);
    if (portValue == null || portValue <= 0 || portValue > 65535) {
      ToastService().showToast(
        appLocalizationsNoContext().validationPortInvalid,
      );
      return;
    }
    final proxyState = state.proxyState;
    proxyState.port = port;
    proxyState.user = userController.text.trim();
    proxyState.pass = passController.text.trim();
    proxyState.removeWhitespace();
    context.pop<InboundLocalProxyState>(proxyState);
  }

  @override
  Future<void> close() {
    portController.dispose();
    userController.dispose();
    passController.dispose();
    return super.close();
  }
}
