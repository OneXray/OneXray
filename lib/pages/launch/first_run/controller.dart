import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/service/tun_setting/interface.dart';
import 'package:onexray/service/tun_setting/state.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';

class FirstRunState {
  final SimpleCountry country;
  final List<NetworkInterface> interfaces;
  final String interface;

  const FirstRunState({
    this.country = SimpleCountry.cn,
    this.interfaces = const [],
    this.interface = "",
  });

  FirstRunState copyWith({
    SimpleCountry? country,
    List<NetworkInterface>? interfaces,
    String? interface,
  }) {
    return FirstRunState(
      country: country ?? this.country,
      interfaces: interfaces ?? this.interfaces,
      interface: interface ?? this.interface,
    );
  }
}

class FirstRunController extends Cubit<FirstRunState> {
  FirstRunController() : super(const FirstRunState()) {
    _readNetworkInterfaces();
  }

  Future<void> _readNetworkInterfaces() async {
    final interfaces = await queryInterfaceList();
    String interfaceName = "";
    if (interfaces.isNotEmpty) {
      interfaceName = interfaces.first.name;
    }
    emit(state.copyWith(interfaces: interfaces, interface: interfaceName));
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

  Future<void> nextStep(BuildContext context) async {
    await _initSimpleSetting();
    await _initTunSetting();
    await PreferencesKey().saveFirstRun(false);
    if (context.mounted) {
      context.go(RouterPath.home);
    }
  }

  Future<void> _initSimpleSetting() async {
    await PreferencesKey().saveXraySettingId(XraySettingSimple.simpleId);
    final simple = XraySettingSimple();
    simple.routing.directSet = state.country;
    await simple.saveToPreferences();
  }

  Future<void> _initTunSetting() async {
    if (state.interface.isNotEmpty) {
      final tunSetting = TunSettingState();
      tunSetting.bindInterface = state.interface;
      await tunSetting.saveToPreferences();
    }
  }
}
