import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';

class XraySettingSimpleCubitState {
  final XraySettingSimple xraySetting;
  final int version;

  const XraySettingSimpleCubitState({
    required this.xraySetting,
    this.version = 0,
  });

  factory XraySettingSimpleCubitState.initial() => XraySettingSimpleCubitState(
        xraySetting: XraySettingSimple(),
      );

  XraySettingSimpleCubitState bumped() => XraySettingSimpleCubitState(
        xraySetting: xraySetting,
        version: version + 1,
      );
}

class XraySettingSimpleController extends Cubit<XraySettingSimpleCubitState> {
  XraySettingSimpleController() : super(XraySettingSimpleCubitState.initial()) {
    _readXraySetting();
  }

  Future<void> _readXraySetting() async {
    final xraySetting = XraySettingSimple();
    await xraySetting.readFromPreferences();
    emit(XraySettingSimpleCubitState(xraySetting: xraySetting, version: 1));
  }

  void updateEnableLog(bool value) {
    state.xraySetting.enableLog = value; emit(state.bumped());
  }

  void updateDomainStrategy(String value) {
    final domainStrategy = RoutingDomainStrategy.fromString(value);
    if (domainStrategy != null) {
      state.xraySetting.routing.domainStrategy = domainStrategy;
    emit(state.bumped());
    }
  }

  void updateQueryStrategy(String value) {
    final queryStrategy = DnsQueryStrategy.fromString(value);
    if (queryStrategy != null) {
      state.xraySetting.routing.queryStrategy = queryStrategy;
    emit(state.bumped());
    }
  }

  void updateDirectSet(String value) {
    final directSet = SimpleCountry.fromString(value);
    if (directSet != null) {
      state.xraySetting.routing.directSet = directSet;
    emit(state.bumped());
    }
  }

  void updateAppleDirect(bool value) {
    state.xraySetting.routing.appleDirect = value;
    emit(state.bumped());
  }

  void updateLocalDirect(bool value) {
    state.xraySetting.routing.localDirect = value;
    emit(state.bumped());
  }

  void updateEnableIPRule(bool value) {
    state.xraySetting.routing.enableIPRule = value;
    emit(state.bumped());
  }

  void updateLocalDns(bool value) {
    state.xraySetting.routing.localDns = value;
    emit(state.bumped());
  }

  Future<void> updateDnsId(int? id) async {
    if (id != null) {
      final dnsId = SimpleDns.fromInt(id);
      state.xraySetting.dns = dnsId; emit(state.bumped());
    }
  }

  Future<void> save(BuildContext context) async {
    await state.xraySetting.saveToPreferences();
    final eventBus = AppEventBus.instance;
    if (XraySettingSimple.simpleId == eventBus.state.xraySettingId) {
      eventBus.updateXraySettingId(eventBus.state.xraySettingId);
    }
    if (context.mounted) {
      context.pop();
    }
  }
}
