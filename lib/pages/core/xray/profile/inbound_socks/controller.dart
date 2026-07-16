import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/inbound_socks/params.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';

class InboundSocksPageState {
  final InboundSocksState socksState;

  const InboundSocksPageState({required this.socksState});

  factory InboundSocksPageState.initial() =>
      InboundSocksPageState(socksState: InboundSocksState());
}

class InboundSocksController extends PageCubit<InboundSocksPageState> {
  final InboundSocksParams params;

  InboundSocksController(this.params) : super(InboundSocksPageState.initial()) {
    _initParams();
  }

  final portController = TextEditingController();
  final userController = TextEditingController();
  final passController = TextEditingController();

  void _initParams() {
    final socksState = params.state.copy();
    portController.text = socksState.port;
    userController.text = socksState.user;
    passController.text = socksState.pass;
    emit(InboundSocksPageState(socksState: socksState));
  }

  void updateListen(String value) {
    state.socksState.listen = value;
    emit(InboundSocksPageState(socksState: state.socksState));
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
    final socksState = state.socksState;
    socksState.port = port;
    socksState.user = userController.text.trim();
    socksState.pass = passController.text.trim();
    socksState.removeWhitespace();
    if (_needsOpenProxyConfirmation(socksState)) {
      final confirmed = await _showOpenProxyDialog(context);
      if (confirmed != true || !context.mounted) {
        return;
      }
    }
    context.pop<InboundSocksState>(socksState);
  }

  bool _needsOpenProxyConfirmation(InboundSocksState socksState) {
    return socksState.listen == InboundSocksState.allInterfacesListen &&
        !socksState.authEnabled;
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
