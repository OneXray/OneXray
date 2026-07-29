import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/params.dart';
import 'package:onexray/pages/core/xray/profile/inbound_additional/view_data.dart';
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

  AdditionalInboundViewData buildViewData(AppLocalizations localizations) {
    final inbound = state.inbound;
    final editableListen = inbound is AuthenticatedAdditionalInboundState;
    final listen = editableListen
        ? inbound.listen
        : AdditionalInboundState.localListen;
    final target = inbound is InboundDokodemoDoorState
        ? AdditionalInboundTargetViewData(
            network: inbound.network.name,
            networkOptions: DokodemoDoorNetwork.values
                .map(
                  (network) => AdditionalInboundOptionViewData(
                    value: network.name,
                    title: network.name,
                  ),
                )
                .toList(growable: false),
          )
        : null;

    return AdditionalInboundViewData(
      pageTitle: _pageTitle(localizations, inbound.type),
      listener: AdditionalInboundListenerViewData(
        editable: editableListen,
        value: listen,
        displayValue: editableListen
            ? _listenTitle(localizations, listen)
            : listen,
        warning:
            editableListen &&
                listen == AdditionalInboundState.allInterfacesListen
            ? localizations.inboundAdditionalPageAllInterfacesWarning
            : null,
        protocolName: _protocolName(inbound.type),
        options: editableListen
            ? AdditionalInboundState.listenValues
                  .map(
                    (value) => AdditionalInboundOptionViewData(
                      value: value,
                      title: _listenTitle(localizations, value),
                    ),
                  )
                  .toList(growable: false)
            : const [],
      ),
      showsAuthentication: editableListen,
      showsUdp: inbound is InboundSocksState,
      target: target,
    );
  }

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

  void updateNetwork(String value) {
    final inbound = state.inbound;
    if (inbound is! InboundDokodemoDoorState) {
      return;
    }
    for (final network in DokodemoDoorNetwork.values) {
      if (network.name == value) {
        inbound.network = network;
        emit(state.bumped());
        return;
      }
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

  String _pageTitle(
    AppLocalizations localizations,
    AdditionalInboundType type,
  ) {
    return switch (type) {
      AdditionalInboundType.socks =>
        localizations.inboundAdditionalPageSocksTitle,
      AdditionalInboundType.http =>
        localizations.inboundAdditionalPageHttpTitle,
      AdditionalInboundType.dokodemoDoor =>
        localizations.inboundAdditionalPageDokodemoDoorTitle,
    };
  }

  String _listenTitle(AppLocalizations localizations, String value) {
    return value == AdditionalInboundState.allInterfacesListen
        ? localizations.inboundAdditionalPageAllInterfaces
        : localizations.inboundAdditionalPageLocalhost;
  }

  String _protocolName(AdditionalInboundType type) {
    return switch (type) {
      AdditionalInboundType.socks => 'socks',
      AdditionalInboundType.http => 'http',
      AdditionalInboundType.dokodemoDoor => 'dokodemo-door',
    };
  }
}
