import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/service/xray/profile/additional_inbound_state.dart';

class AdditionalInboundPageState {
  final AdditionalInboundState inbound;
  final int version;

  const AdditionalInboundPageState({required this.inbound, this.version = 0});

  AdditionalInboundPageState bumped() =>
      AdditionalInboundPageState(inbound: inbound, version: version + 1);
}

class AdditionalInboundController
    extends PageCubit<AdditionalInboundPageState> {
  AdditionalInboundController(this.params)
    : super(AdditionalInboundPageState(inbound: params.state.copy())) {
    _initInputs();
  }

  final AdditionalInboundParams params;

  final portController = TextEditingController();
  final tagController = TextEditingController();
  final userController = TextEditingController();
  final passwordController = TextEditingController();
  final targetAddressController = TextEditingController();
  final targetPortController = TextEditingController();

  void _initInputs() {
    final inbound = state.inbound;
    portController.text = inbound.port;
    tagController.text = inbound.tag;
    if (inbound is AuthenticatedAdditionalInboundState) {
      userController.text = inbound.user;
      passwordController.text = inbound.pass;
    }
    if (inbound is InboundDokodemoDoorState) {
      targetAddressController.text = inbound.targetAddress;
      targetPortController.text = inbound.targetPort;
    }
  }

  @override
  Future<void> disposePageResources() async {
    portController.dispose();
    tagController.dispose();
    userController.dispose();
    passwordController.dispose();
    targetAddressController.dispose();
    targetPortController.dispose();
  }

  void updateListen(String value) {
    final inbound = state.inbound;
    if (inbound is AuthenticatedAdditionalInboundState &&
        AdditionalInboundState.listenValues.contains(value)) {
      inbound.listen = value;
      emit(state.bumped());
    }
  }

  void updateNetwork(DokodemoDoorNetwork value) {
    final inbound = state.inbound;
    if (inbound is InboundDokodemoDoorState) {
      inbound.network = value;
      emit(state.bumped());
    }
  }

  void save(BuildContext context) {
    final inbound = state.inbound;
    inbound.port = portController.text;
    inbound.tag = tagController.text;
    if (inbound is AuthenticatedAdditionalInboundState) {
      inbound.user = userController.text;
      inbound.pass = passwordController.text;
    }
    if (inbound is InboundDokodemoDoorState) {
      inbound.targetAddress = targetAddressController.text;
      inbound.targetPort = targetPortController.text;
    }
    inbound.removeWhitespace();

    final error = inbound.validate(
      unavailableTags: params.unavailableTags,
      unavailablePorts: params.unavailablePorts,
    );
    if (error != null) {
      ContextAlert.showToast(context, error);
      return;
    }
    context.pop<AdditionalInboundState>(inbound);
  }
}
