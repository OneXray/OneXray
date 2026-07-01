import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/setting/inbound_http/params.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';

class InboundHttpCubitState {
  final InboundHttpState httpState;

  const InboundHttpCubitState({required this.httpState});

  factory InboundHttpCubitState.initial() =>
      InboundHttpCubitState(httpState: InboundHttpState());
}

class InboundHttpController extends Cubit<InboundHttpCubitState> {
  final InboundHttpParams params;

  InboundHttpController(this.params) : super(InboundHttpCubitState.initial()) {
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
    emit(InboundHttpCubitState(httpState: state));
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
    final httpState = state.httpState;
    httpState.port = port;
    httpState.user = userController.text.trim();
    httpState.pass = passController.text.trim();
    httpState.removeWhitespace();
    context.pop<InboundHttpState>(httpState);
  }

  @override
  Future<void> close() {
    portController.dispose();
    userController.dispose();
    passController.dispose();
    return super.close();
  }
}
