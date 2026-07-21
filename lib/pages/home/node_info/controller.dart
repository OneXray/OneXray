import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/db/config_reader.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/metrics/formatter.dart';

class NodeInfoPageState {
  const NodeInfoPageState({required this.eventState, this.activeConfig});

  final AppEventBusState eventState;
  final CoreConfigData? activeConfig;
}

class NodeInfoViewState {
  const NodeInfoViewState({
    required this.activePathName,
    required this.protocol,
    required this.connectionDetail,
    required this.status,
    required this.connected,
    required this.direct,
    required this.refreshing,
    required this.runMode,
    required this.duration,
    required this.delay,
    required this.traffic,
    required this.ipAddress,
    required this.ipVersion,
    required this.country,
    required this.region,
    required this.city,
  });

  final String activePathName;
  final String protocol;
  final String connectionDetail;
  final String status;
  final bool connected;
  final bool direct;
  final bool refreshing;
  final String? runMode;
  final String duration;
  final String delay;
  final String traffic;
  final String ipAddress;
  final String ipVersion;
  final String country;
  final String region;
  final String city;
}

class NodeInfoController extends PageCubit<NodeInfoPageState> {
  NodeInfoController(this._selectedConfigId)
    : super(NodeInfoPageState(eventState: AppEventBus.instance.state)) {
    _subscription = AppEventBus.instance.stream.listen(_updateEventState);
    unawaited(_loadActiveConfig(AppEventBus.instance.state));
  }

  final int _selectedConfigId;
  StreamSubscription<AppEventBusState>? _subscription;

  Future<void> retryConnectivityTest() {
    return VpnService().retryConnectivityTest();
  }

  void _updateEventState(AppEventBusState eventState) {
    final configChanged =
        _activeConfigId(eventState) != _activeConfigId(state.eventState);
    emit(
      NodeInfoPageState(
        eventState: eventState,
        activeConfig: configChanged ? null : state.activeConfig,
      ),
    );
    if (configChanged) {
      unawaited(_loadActiveConfig(eventState));
    }
  }

  Future<void> _loadActiveConfig(AppEventBusState eventState) async {
    final expectedId = _activeConfigId(eventState);
    if (expectedId == DBConstants.defaultId) {
      return;
    }
    final config = await AppDatabase().coreConfigDao.searchRow(expectedId);
    if (isPageActive && _activeConfigId(state.eventState) == expectedId) {
      emit(
        NodeInfoPageState(eventState: state.eventState, activeConfig: config),
      );
    }
  }

  int _activeConfigId(AppEventBusState eventState) {
    if (eventState.coreRoutingMode == CoreRoutingMode.direct) {
      return DBConstants.defaultId;
    }
    if (eventState.runningId != DBConstants.defaultId) {
      return eventState.runningId;
    }
    return _selectedConfigId;
  }

  NodeInfoViewState buildViewState(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final eventState = state.eventState;
    final location = eventState.location;
    final direct = eventState.coreRoutingMode == CoreRoutingMode.direct;
    final connected = eventState.vpnActionState == VpnActionState.connected;
    final config = state.activeConfig;
    final refreshing =
        eventState.pingProbeState == ConnectivityProbeState.loading ||
        eventState.geoLocationProbeState == ConnectivityProbeState.loading;
    return NodeInfoViewState(
      activePathName: direct
          ? localizations.homePageDirectConnection
          : config?.name ?? localizations.homePageNoSelectedNode,
      protocol: direct ? 'DIRECT' : config?.readProtocolLabel() ?? '',
      connectionDetail: direct
          ? localizations.homePageTrafficNotProxied
          : config?.readConnectionDetail(context) ?? '',
      status: _status(localizations, eventState, direct),
      connected: connected,
      direct: direct,
      refreshing: refreshing,
      runMode: CoreRunModePolicy.proxyEnabled
          ? eventState.coreRunMode.title
          : null,
      duration: location.duration ?? localizations.nodeInfoPageFetching,
      delay: _delayValue(localizations, eventState),
      traffic: XrayMetricsFormatter.formatTraffic(eventState.trafficMetrics),
      ipAddress: _geoValue(localizations, eventState, location.ipAddress),
      ipVersion: _geoValue(localizations, eventState, location.ipVersion),
      country: _geoValue(localizations, eventState, location.country),
      region: _geoValue(localizations, eventState, location.region),
      city: _geoValue(localizations, eventState, location.city),
    );
  }

  String _status(
    AppLocalizations localizations,
    AppEventBusState state,
    bool direct,
  ) {
    return switch (state.vpnActionState) {
      VpnActionState.connected when direct =>
        '${localizations.homePageStatusConnected} · '
            '${localizations.homePageTrafficNotProxied}',
      VpnActionState.connected => localizations.homePageStatusConnected,
      VpnActionState.preparing ||
      VpnActionState.connecting => localizations.homePageStatusConnecting,
      VpnActionState.disconnecting => localizations.homePageStatusDisconnecting,
      VpnActionState.waitingForPlatformPermission =>
        localizations.homePageWaitForApprovalTitle,
      VpnActionState.failed => localizations.nodeInfoPageFailed,
      VpnActionState.idle => localizations.homePageStatusDisconnected,
    };
  }

  String _delayValue(AppLocalizations localizations, AppEventBusState state) {
    return switch (state.pingProbeState) {
      ConnectivityProbeState.idle ||
      ConnectivityProbeState.loading => localizations.nodeInfoPageFetching,
      ConnectivityProbeState.failed => localizations.nodeInfoPageFailed,
      ConnectivityProbeState.success =>
        state.location.delay == null
            ? localizations.nodeInfoPageFailed
            : '${state.location.delay}ms',
    };
  }

  String _geoValue(
    AppLocalizations localizations,
    AppEventBusState state,
    String? value,
  ) {
    return switch (state.geoLocationProbeState) {
      ConnectivityProbeState.idle ||
      ConnectivityProbeState.loading => localizations.nodeInfoPageFetching,
      ConnectivityProbeState.failed => localizations.nodeInfoPageFailed,
      ConnectivityProbeState.success =>
        value ?? localizations.nodeInfoPageFailed,
    };
  }

  @override
  Future<void> disposePageResources() async {
    await _subscription?.cancel();
  }
}
