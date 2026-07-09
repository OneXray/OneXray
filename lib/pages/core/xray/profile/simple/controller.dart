import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/pages/home/outbound_select/params.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:onexray/pages/main/navigation.dart';

class XrayProfileSimplePageState {
  final XrayProfileSimple xrayProfile;
  final String finalOutboundName;
  final int version;

  const XrayProfileSimplePageState({
    required this.xrayProfile,
    this.finalOutboundName = "",
    this.version = 0,
  });

  factory XrayProfileSimplePageState.initial() =>
      XrayProfileSimplePageState(xrayProfile: XrayProfileSimple());

  XrayProfileSimplePageState bumped() => XrayProfileSimplePageState(
    xrayProfile: xrayProfile,
    finalOutboundName: finalOutboundName,
    version: version + 1,
  );

  XrayProfileSimplePageState copyWith({
    XrayProfileSimple? xrayProfile,
    String? finalOutboundName,
    int? version,
  }) {
    return XrayProfileSimplePageState(
      xrayProfile: xrayProfile ?? this.xrayProfile,
      finalOutboundName: finalOutboundName ?? this.finalOutboundName,
      version: version ?? this.version,
    );
  }
}

class XrayProfileSimpleController extends Cubit<XrayProfileSimplePageState> {
  XrayProfileSimpleController() : super(XrayProfileSimplePageState.initial()) {
    _readXrayProfile();
  }

  Future<void> _readXrayProfile() async {
    final xrayProfile = XrayProfileSimple();
    await xrayProfile.readFromPreferences();
    final finalOutboundName = await _readFinalOutboundName(
      xrayProfile.finalOutboundId,
    );
    emit(
      XrayProfileSimplePageState(
        xrayProfile: xrayProfile,
        finalOutboundName: finalOutboundName,
        version: 1,
      ),
    );
  }

  Future<String> _readFinalOutboundName(int? id) async {
    if (id == null) {
      return "";
    }
    final row = await AppDatabase().coreConfigDao.searchRow(id);
    return row?.name ?? "";
  }

  void updateEnableLog(bool value) {
    state.xrayProfile.enableLog = value;
    emit(state.bumped());
  }

  void updateFakeDns(bool value) {
    state.xrayProfile.fakeDns = value;
    emit(state.bumped());
  }

  void updateDomainStrategy(String value) {
    final domainStrategy = RoutingDomainStrategy.fromString(value);
    if (domainStrategy != null) {
      state.xrayProfile.routing.domainStrategy = domainStrategy;
      emit(state.bumped());
    }
  }

  void updateDirectSet(String value) {
    final directSet = SimpleCountry.fromString(value);
    if (directSet != null) {
      state.xrayProfile.routing.directSet = directSet;
      emit(state.bumped());
    }
  }

  void updateAppleDirect(bool value) {
    state.xrayProfile.routing.appleDirect = value;
    emit(state.bumped());
  }

  void updateLocalDirect(bool value) {
    state.xrayProfile.routing.localDirect = value;
    emit(state.bumped());
  }

  void updateEnableIPRule(bool value) {
    state.xrayProfile.routing.enableIPRule = value;
    emit(state.bumped());
  }

  void updateLocalDns(bool value) {
    state.xrayProfile.routing.localDns = value;
    emit(state.bumped());
  }

  void updateBlockAds(bool value) {
    state.xrayProfile.routing.blockAds = value;
    emit(state.bumped());
  }

  Future<void> updateDnsId(int? id) async {
    if (id != null) {
      final dnsId = SimpleDns.fromInt(id);
      state.xrayProfile.dns = dnsId;
      emit(state.bumped());
    }
  }

  Future<void> editFinalOutbound(BuildContext context) async {
    final params = OutboundSelectParams(
      selectedId: state.xrayProfile.finalOutboundId,
    );
    final outbound = await context.pushScoped<CoreConfigData>(
      AppSecondaryDestination.outboundSelect,
      extra: params,
    );
    if (outbound != null) {
      state.xrayProfile.finalOutboundId = outbound.id;
      emit(
        state.copyWith(
          finalOutboundName: outbound.name,
          version: state.version + 1,
        ),
      );
    }
  }

  void clearFinalOutbound() {
    state.xrayProfile.finalOutboundId = null;
    emit(state.copyWith(finalOutboundName: "", version: state.version + 1));
  }

  Future<void> save(BuildContext context) async {
    await state.xrayProfile.saveToPreferences();
    final eventBus = AppEventBus.instance;
    if (XrayProfileSimple.simpleId == eventBus.state.xrayProfileId) {
      eventBus.updateXrayProfileId(eventBus.state.xrayProfileId);
    }
    if (context.mounted) {
      context.pop();
    }
  }
}
