import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/metrics/formatter.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';

class HomePageState {
  final int configId;
  final String configName;
  final String xrayProfileName;
  final bool nodeSearchVisible;
  final bool vpnCommandLoading;

  const HomePageState({
    required this.configId,
    required this.configName,
    required this.xrayProfileName,
    required this.nodeSearchVisible,
    required this.vpnCommandLoading,
  });

  factory HomePageState.initial({int xrayProfileId = DBConstants.defaultId}) =>
      HomePageState(
        configId: DBConstants.defaultId,
        configName: '',
        xrayProfileName: _initialXrayProfileName(xrayProfileId),
        nodeSearchVisible: false,
        vpnCommandLoading: false,
      );

  HomePageState copyWith({
    int? configId,
    String? configName,
    String? xrayProfileName,
    bool? nodeSearchVisible,
    bool? vpnCommandLoading,
  }) {
    return HomePageState(
      configId: configId ?? this.configId,
      configName: configName ?? this.configName,
      xrayProfileName: xrayProfileName ?? this.xrayProfileName,
      nodeSearchVisible: nodeSearchVisible ?? this.nodeSearchVisible,
      vpnCommandLoading: vpnCommandLoading ?? this.vpnCommandLoading,
    );
  }
}

String _initialXrayProfileName(int xrayProfileId) {
  switch (xrayProfileId) {
    case DBConstants.defaultId:
    case XrayProfileSimple.simpleId:
      return appLocalizationsNoContext().xrayProfileListPageSimple;
    default:
      return '';
  }
}

enum HomeConnectionTone {
  disconnected,
  connecting,
  connected,
  waitingForApproval,
  failed,
}

class HomeConnectionViewPageState {
  final HomeConnectionTone tone;
  final bool connected;
  final bool loading;
  final String statusText;
  final String nodeName;
  final String detailText;
  final String? summaryDetailText;
  final String trafficText;
  final String metricsText;
  final IconData statusIcon;
  final IconData actionIcon;

  const HomeConnectionViewPageState({
    required this.tone,
    required this.connected,
    required this.loading,
    required this.statusText,
    required this.nodeName,
    required this.detailText,
    required this.summaryDetailText,
    required this.trafficText,
    required this.metricsText,
    required this.statusIcon,
    required this.actionIcon,
  });
}

final class HomeConnectionViewStateBuilder {
  const HomeConnectionViewStateBuilder._();

  static HomeConnectionViewPageState build(
    BuildContext context,
    HomePageState homeState,
    AppEventBusState eventState,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final connected = eventState.runningId != DBConstants.defaultId;
    final waitingForMacApproval = _isWaitingForMacApproval(eventState);
    final failed = eventState.vpnActionState == VpnActionState.failed;
    final nodeName = homeState.configName.isEmpty
        ? localizations.homePageNoSelectedNode
        : homeState.configName;
    final tone = _connectionTone(
      eventState,
      connected,
      waitingForMacApproval,
      failed,
    );
    final statusText = _connectionStatusText(
      localizations,
      eventState,
      connected,
      waitingForMacApproval,
      failed,
    );
    final detailText = failed && eventState.vpnErrorMessage.isNotEmpty
        ? eventState.vpnErrorMessage
        : waitingForMacApproval
        ? localizations.homePageWaitForApprovalTips
        : connected
        ? _formatGeoLocation(localizations, eventState)
        : '${localizations.homePageCurrentNode}: $nodeName';
    final summaryDetailText = failed || waitingForMacApproval
        ? detailText
        : null;
    final disconnected = eventState.runningId == DBConstants.defaultId;
    final actionIcon = failed
        ? Icons.error_outline
        : waitingForMacApproval
        ? Icons.admin_panel_settings
        : disconnected
        ? Icons.public
        : Icons.private_connectivity;
    return HomeConnectionViewPageState(
      tone: tone,
      connected: connected,
      loading: eventState.vpnLoading || homeState.vpnCommandLoading,
      statusText: statusText,
      nodeName: nodeName,
      detailText: detailText,
      summaryDetailText: summaryDetailText,
      trafficText: XrayMetricsFormatter.formatTraffic(
        eventState.trafficMetrics,
      ),
      metricsText: _formatSummaryMetrics(localizations, eventState),
      statusIcon: actionIcon,
      actionIcon: actionIcon,
    );
  }

  static HomeConnectionTone _connectionTone(
    AppEventBusState eventState,
    bool connected,
    bool waitingForMacApproval,
    bool failed,
  ) {
    if (waitingForMacApproval) {
      return HomeConnectionTone.waitingForApproval;
    }
    if (failed) {
      return HomeConnectionTone.failed;
    }
    if (eventState.vpnLoading) {
      return HomeConnectionTone.connecting;
    }
    if (connected) {
      return HomeConnectionTone.connected;
    }
    return HomeConnectionTone.disconnected;
  }

  static String _connectionStatusText(
    AppLocalizations localizations,
    AppEventBusState eventState,
    bool connected,
    bool waitingForMacApproval,
    bool failed,
  ) {
    if (waitingForMacApproval) {
      return localizations.homePageWaitForApprovalTitle;
    }
    if (failed) {
      return localizations.nodeInfoPageFailed;
    }
    if (eventState.vpnActionState == VpnActionState.disconnecting) {
      return localizations.homePageStatusDisconnecting;
    }
    if (eventState.vpnLoading) {
      return localizations.homePageStatusConnecting;
    }
    if (connected) {
      return localizations.homePageStatusConnected;
    }
    return localizations.homePageStatusDisconnected;
  }

  static bool _isWaitingForMacApproval(AppEventBusState eventState) {
    return eventState.platformPermissionKind ==
            PlatformPermissionKind.macosSystemExtension &&
        eventState.platformPermissionState ==
            PlatformPermissionState.awaitingUserApproval;
  }

  static String _formatGeoLocation(
    AppLocalizations localizations,
    AppEventBusState eventState,
  ) {
    final location = eventState.location;
    return '${localizations.nodeInfoPageDuration}: '
        '${location.duration ?? localizations.nodeInfoPageFetching} '
        '${localizations.nodeInfoPageDelay}: '
        '${_formatDelay(localizations, eventState)} '
        '${localizations.nodeInfoPageLocation}: '
        '${_formatGeoValue(localizations, eventState, location.country)} ';
  }

  static String _formatSummaryMetrics(
    AppLocalizations localizations,
    AppEventBusState eventState,
  ) {
    final location = eventState.location;
    final duration = location.duration ?? localizations.nodeInfoPageFetching;
    final country = _formatGeoValue(
      localizations,
      eventState,
      location.country,
    );
    final delay = _formatDelay(localizations, eventState);
    return '$duration · $country · $delay';
  }

  static String _formatDelay(
    AppLocalizations localizations,
    AppEventBusState eventState,
  ) {
    switch (eventState.pingProbeState) {
      case ConnectivityProbeState.idle:
      case ConnectivityProbeState.loading:
        return localizations.nodeInfoPageFetching;
      case ConnectivityProbeState.failed:
        return localizations.nodeInfoPageFailed;
      case ConnectivityProbeState.success:
        final delay = eventState.location.delay;
        return delay == null ? localizations.nodeInfoPageFailed : '${delay}ms';
    }
  }

  static String _formatGeoValue(
    AppLocalizations localizations,
    AppEventBusState eventState,
    String? value,
  ) {
    switch (eventState.geoLocationProbeState) {
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
