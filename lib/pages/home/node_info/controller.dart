import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/metrics/formatter.dart';

class NodeInfoViewState {
  final String duration;
  final String delay;
  final String traffic;
  final String ipAddress;
  final String ipVersion;
  final String country;
  final String region;
  final String city;

  const NodeInfoViewState({
    required this.duration,
    required this.delay,
    required this.traffic,
    required this.ipAddress,
    required this.ipVersion,
    required this.country,
    required this.region,
    required this.city,
  });
}

class NodeInfoController {
  Future<void> retryConnectivityTest() {
    return VpnService().retryConnectivityTest();
  }

  NodeInfoViewState buildViewState(
    BuildContext context,
    AppEventBusState state,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final location = state.location;
    return NodeInfoViewState(
      duration: location.duration ?? localizations.nodeInfoPageFetching,
      delay: _delayValue(localizations, state),
      traffic: XrayMetricsFormatter.formatTraffic(state.trafficMetrics),
      ipAddress: _geoValue(localizations, state, location.ipAddress),
      ipVersion: _geoValue(localizations, state, location.ipVersion),
      country: _geoValue(localizations, state, location.country),
      region: _geoValue(localizations, state, location.region),
      city: _geoValue(localizations, state, location.city),
    );
  }

  String _delayValue(AppLocalizations localizations, AppEventBusState state) {
    switch (state.pingProbeState) {
      case ConnectivityProbeState.idle:
      case ConnectivityProbeState.loading:
        return localizations.nodeInfoPageFetching;
      case ConnectivityProbeState.failed:
        return localizations.nodeInfoPageFailed;
      case ConnectivityProbeState.success:
        final delay = state.location.delay;
        return delay == null ? localizations.nodeInfoPageFailed : '${delay}ms';
    }
  }

  String _geoValue(
    AppLocalizations localizations,
    AppEventBusState state,
    String? value,
  ) {
    switch (state.geoLocationProbeState) {
      case ConnectivityProbeState.idle:
      case ConnectivityProbeState.loading:
        return localizations.nodeInfoPageFetching;
      case ConnectivityProbeState.failed:
        return localizations.nodeInfoPageFailed;
      case ConnectivityProbeState.success:
        return value ?? localizations.nodeInfoPageFailed;
    }
  }
}
