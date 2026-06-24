import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/home/outbound_select/params.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/setting/enum.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';
import 'package:onexray/pages/main/navigation.dart';

class XraySettingSimpleCubitState {
  final XraySettingSimple xraySetting;
  final String chainProxyName;
  final int version;

  const XraySettingSimpleCubitState({
    required this.xraySetting,
    this.chainProxyName = "",
    this.version = 0,
  });

  factory XraySettingSimpleCubitState.initial() =>
      XraySettingSimpleCubitState(xraySetting: XraySettingSimple());

  XraySettingSimpleCubitState bumped() => XraySettingSimpleCubitState(
    xraySetting: xraySetting,
    chainProxyName: chainProxyName,
    version: version + 1,
  );

  XraySettingSimpleCubitState copyWith({
    XraySettingSimple? xraySetting,
    String? chainProxyName,
    int? version,
  }) {
    return XraySettingSimpleCubitState(
      xraySetting: xraySetting ?? this.xraySetting,
      chainProxyName: chainProxyName ?? this.chainProxyName,
      version: version ?? this.version,
    );
  }
}

class XraySettingSimpleController extends Cubit<XraySettingSimpleCubitState> {
  XraySettingSimpleController() : super(XraySettingSimpleCubitState.initial()) {
    _readXraySetting();
  }

  Future<void> _readXraySetting() async {
    final xraySetting = XraySettingSimple();
    await xraySetting.readFromPreferences();
    final chainProxyName = await _readChainProxyName(
      xraySetting.chainProxyOutboundId,
    );
    emit(
      XraySettingSimpleCubitState(
        xraySetting: xraySetting,
        chainProxyName: chainProxyName,
        version: 1,
      ),
    );
  }

  Future<String> _readChainProxyName(int? id) async {
    if (id == null) {
      return "";
    }
    final row = await AppDatabase().coreConfigDao.searchRow(id);
    return row?.name ?? "";
  }

  void updateEnableLog(bool value) {
    state.xraySetting.enableLog = value;
    emit(state.bumped());
  }

  void updateFakeDns(bool value) {
    state.xraySetting.fakeDns = value;
    emit(state.bumped());
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
      state.xraySetting.dns = dnsId;
      emit(state.bumped());
    }
  }

  Future<void> editChainProxy(BuildContext context) async {
    final params = OutboundSelectParams(
      selectedId: state.xraySetting.chainProxyOutboundId,
    );
    final outbound = await context.pushScoped<CoreConfigData>(
      AppSecondaryDestination.outboundSelect,
      extra: params,
    );
    if (outbound != null) {
      state.xraySetting.chainProxyOutboundId = outbound.id;
      emit(
        state.copyWith(
          chainProxyName: outbound.name,
          version: state.version + 1,
        ),
      );
    }
  }

  void clearChainProxy() {
    state.xraySetting.chainProxyOutboundId = null;
    emit(state.copyWith(chainProxyName: "", version: state.version + 1));
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
