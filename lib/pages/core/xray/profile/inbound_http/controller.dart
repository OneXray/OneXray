import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/inbound_http/params.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';

class InboundHttpPageState {
  final InboundHttpState httpState;

  const InboundHttpPageState({required this.httpState});

  factory InboundHttpPageState.initial() =>
      InboundHttpPageState(httpState: InboundHttpState());
}

class InboundHttpController extends PageCubit<InboundHttpPageState> {
  final InboundHttpParams params;

  InboundHttpController(this.params) : super(InboundHttpPageState.initial()) {
    _initParams();
  }

  final portController = TextEditingController();
  final userController = TextEditingController();
  final passController = TextEditingController();

  void _initParams() {
    final httpState = params.state.copy();
    portController.text = httpState.port;
    userController.text = httpState.user;
    passController.text = httpState.pass;
    emit(InboundHttpPageState(httpState: httpState));
  }

  void updateListen(String value) {
    state.httpState.listen = value;
    emit(InboundHttpPageState(httpState: state.httpState));
  }

  Future<void> save(BuildContext context) async {
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
    if (_needsOpenProxyConfirmation(httpState)) {
      final confirmed = await _showOpenProxyDialog(context);
      if (confirmed != true || !context.mounted) {
        return;
      }
    }
    context.pop<InboundHttpState>(httpState);
  }

  bool _needsOpenProxyConfirmation(InboundHttpState httpState) {
    return httpState.listen == InboundHttpState.allInterfacesListen &&
        !httpState.authEnabled;
  }

  Future<bool?> _showOpenProxyDialog(BuildContext context) {
    final localizations = appLocalizationsNoContext();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.inboundProxyPageOpenProxyWarningTitle),
        content: Text(localizations.inboundProxyPageOpenProxyWarningContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.buttonOK),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> disposePageResources() async {
    portController.dispose();
    userController.dispose();
    passController.dispose();
  }
}
