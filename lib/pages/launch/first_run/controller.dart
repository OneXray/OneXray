import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/tun_settings/interface.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';

class FirstRunPageState {
  final SimpleCountry country;
  final List<NetworkInterface> interfaces;
  final String interface;
  final bool enableIPv6;

  const FirstRunPageState({
    this.country = SimpleCountry.cn,
    this.interfaces = const [],
    this.interface = TunSettingsState.autoOutboundsInterfaceAuto,
    this.enableIPv6 = true,
  });

  FirstRunPageState copyWith({
    SimpleCountry? country,
    List<NetworkInterface>? interfaces,
    String? interface,
    bool? enableIPv6,
  }) {
    return FirstRunPageState(
      country: country ?? this.country,
      interfaces: interfaces ?? this.interfaces,
      interface: interface ?? this.interface,
      enableIPv6: enableIPv6 ?? this.enableIPv6,
    );
  }
}

class FirstRunController extends Cubit<FirstRunPageState> {
  FirstRunController() : super(const FirstRunPageState()) {
    _readNetworkInterfaces();
  }

  Future<void> _readNetworkInterfaces() async {
    final interfaces = await queryInterfaceList();
    emit(state.copyWith(interfaces: interfaces));
  }

  void updateCountry(SimpleCountry? value) {
    if (value != null) {
      emit(state.copyWith(country: value));
    }
  }

  void updateInterface(String? value) {
    if (value != null) {
      emit(state.copyWith(interface: value));
    }
  }

  void updateEnableIPv6(bool value) {
    emit(state.copyWith(enableIPv6: value));
  }

  Future<void> nextStep(BuildContext context) async {
    await _initSimpleSetting();
    await _initTunSettings();
    await PreferencesKey().saveFirstRun(false);
    if (context.mounted) {
      context.go(RouterPath.home);
    }
  }

  Future<void> _initSimpleSetting() async {
    final simple = XrayProfileSimple();
    simple.routing.directSet = state.country;
    await PreferencesKey().saveXrayProfileId(XrayProfileSimple.simpleId);
    await simple.saveToPreferences();
    AppEventBus.instance.updateXrayProfileId(XrayProfileSimple.simpleId);
  }

  Future<void> _initTunSettings() async {
    final tunSettings = TunSettingsState();
    tunSettings.autoOutboundsInterface = state.interface;
    tunSettings.enableIPv6 = state.enableIPv6;
    await tunSettings.saveToPreferences();
  }
}
