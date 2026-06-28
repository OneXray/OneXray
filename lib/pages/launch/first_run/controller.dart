import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/tun_setting/interface.dart';
import 'package:onexray/service/tun_setting/state.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';

class FirstRunState {
  final SimpleCountry country;
  final List<NetworkInterface> interfaces;
  final String interface;
  final bool enableIPv6;

  const FirstRunState({
    this.country = SimpleCountry.cn,
    this.interfaces = const [],
    this.interface = TunSettingState.autoOutboundsInterfaceAuto,
    this.enableIPv6 = true,
  });

  FirstRunState copyWith({
    SimpleCountry? country,
    List<NetworkInterface>? interfaces,
    String? interface,
    bool? enableIPv6,
  }) {
    return FirstRunState(
      country: country ?? this.country,
      interfaces: interfaces ?? this.interfaces,
      interface: interface ?? this.interface,
      enableIPv6: enableIPv6 ?? this.enableIPv6,
    );
  }
}

class FirstRunController extends Cubit<FirstRunState> {
  FirstRunController() : super(const FirstRunState()) {
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
    await _initTunSetting();
    await PreferencesKey().saveFirstRun(false);
    if (context.mounted) {
      context.go(RouterPath.home);
    }
  }

  Future<void> _initSimpleSetting() async {
    final simple = XraySettingSimple();
    simple.routing.directSet = state.country;
    await PreferencesKey().saveXraySettingId(XraySettingSimple.simpleId);
    await simple.saveToPreferences();
    AppEventBus.instance.updateXraySettingId(XraySettingSimple.simpleId);
  }

  Future<void> _initTunSetting() async {
    final tunSetting = TunSettingState();
    tunSetting.autoOutboundsInterface = state.interface;
    tunSetting.enableIPv6 = state.enableIPv6;
    await tunSetting.saveToPreferences();
  }
}
