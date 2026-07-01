import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/setting/inbound_socks/params.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';

class InboundSocksCubitState {
  final InboundSocksState socksState;

  const InboundSocksCubitState({required this.socksState});

  factory InboundSocksCubitState.initial() =>
      InboundSocksCubitState(socksState: InboundSocksState());
}

class InboundSocksController extends Cubit<InboundSocksCubitState> {
  final InboundSocksParams params;

  InboundSocksController(this.params)
    : super(InboundSocksCubitState.initial()) {
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
    emit(InboundSocksCubitState(socksState: state));
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
    final socksState = state.socksState;
    socksState.port = port;
    socksState.user = userController.text.trim();
    socksState.pass = passController.text.trim();
    socksState.removeWhitespace();
    context.pop<InboundSocksState>(socksState);
  }

  @override
  Future<void> close() {
    portController.dispose();
    userController.dispose();
    passController.dispose();
    return super.close();
  }
}
