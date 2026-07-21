import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/core_routing_mode/state.dart';
import 'package:onexray/service/core_run_mode/state.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/xray/metrics/formatter.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';

class HomePageState {
  final int configId;
  final String configName;
  final int runtimeConfigId;
  final String runtimeConfigName;
  final String xrayProfileName;
  final bool nodeSearchVisible;
  final bool vpnCommandLoading;
  final CoreRoutingMode? pendingRoutingMode;

  const HomePageState({
    required this.configId,
    required this.configName,
    required this.runtimeConfigId,
    required this.runtimeConfigName,
    required this.xrayProfileName,
    required this.nodeSearchVisible,
    required this.vpnCommandLoading,
    required this.pendingRoutingMode,
  });

  factory HomePageState.initial({int xrayProfileId = DBConstants.defaultId}) =>
      HomePageState(
        configId: DBConstants.defaultId,
        configName: '',
        runtimeConfigId: DBConstants.defaultId,
        runtimeConfigName: '',
        xrayProfileName: _initialXrayProfileName(xrayProfileId),
        nodeSearchVisible: false,
        vpnCommandLoading: false,
        pendingRoutingMode: null,
      );

  HomePageState copyWith({
    int? configId,
    String? configName,
    int? runtimeConfigId,
    String? runtimeConfigName,
    String? xrayProfileName,
    bool? nodeSearchVisible,
    bool? vpnCommandLoading,
    CoreRoutingMode? pendingRoutingMode,
    bool clearPendingRoutingMode = false,
  }) {
    return HomePageState(
      configId: configId ?? this.configId,
      configName: configName ?? this.configName,
      runtimeConfigId: runtimeConfigId ?? this.runtimeConfigId,
      runtimeConfigName: runtimeConfigName ?? this.runtimeConfigName,
      xrayProfileName: xrayProfileName ?? this.xrayProfileName,
      nodeSearchVisible: nodeSearchVisible ?? this.nodeSearchVisible,
      vpnCommandLoading: vpnCommandLoading ?? this.vpnCommandLoading,
      pendingRoutingMode: clearPendingRoutingMode
          ? null
          : pendingRoutingMode ?? this.pendingRoutingMode,
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
  final bool destructiveAction;
  final String actionLabel;
  final String statusText;
  final String nodeName;
  final String? summaryDetailText;
  final String locationText;
  final String downloadText;
  final String uploadText;
  final String? runModeText;
  final IconData statusIcon;

  const HomeConnectionViewPageState({
    required this.tone,
    required this.connected,
    required this.loading,
    required this.destructiveAction,
    required this.actionLabel,
    required this.statusText,
    required this.nodeName,
    required this.summaryDetailText,
    required this.locationText,
    required this.downloadText,
    required this.uploadText,
    required this.runModeText,
    required this.statusIcon,
  });
}

final class HomeConnectionViewStateBuilder {
  const HomeConnectionViewStateBuilder._();

  static const emptyNodeName = '--';

  static HomeConnectionViewPageState build(
    BuildContext context,
    HomePageState homeState,
    AppEventBusState eventState,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final connected = eventState.vpnActionState == VpnActionState.connected;
    final direct = eventState.coreRoutingMode == CoreRoutingMode.direct;
    final activeCore = _hasActiveCore(eventState);
    final destructiveAction = _isDisconnectAction(
      homeState,
      eventState,
      direct,
      activeCore,
    );
    final waitingForMacApproval = _isWaitingForMacApproval(eventState);
    final failed = eventState.vpnActionState == VpnActionState.failed;
    final nodeName = _nodeName(homeState, eventState);
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
      direct,
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
    final actionIcon = failed
        ? LucideIcons.shieldAlert
        : waitingForMacApproval
        ? LucideIcons.shieldAlert
        : connected
        ? LucideIcons.shieldCheck
        : LucideIcons.shieldOff;
    return HomeConnectionViewPageState(
      tone: tone,
      connected: connected,
      loading: eventState.vpnLoading || homeState.vpnCommandLoading,
      destructiveAction: destructiveAction,
      actionLabel: _connectionActionLabel(
        localizations,
        homeState,
        eventState,
        direct,
        activeCore,
      ),
      statusText: statusText,
      nodeName: nodeName,
      summaryDetailText: summaryDetailText,
      locationText: _formatGeoValue(
        localizations,
        eventState,
        eventState.location.country,
      ),
      downloadText: eventState.trafficMetrics.available
          ? XrayMetricsFormatter.formatSpeed(
              eventState.trafficMetrics.downloadSpeed,
            )
          : '--',
      uploadText: eventState.trafficMetrics.available
          ? XrayMetricsFormatter.formatSpeed(
              eventState.trafficMetrics.uploadSpeed,
            )
          : '--',
      runModeText: CoreRunModePolicy.proxyEnabled
          ? eventState.coreRunMode.title
          : null,
      statusIcon: actionIcon,
    );
  }

  static int runtimeConfigId(AppEventBusState eventState) {
    if (eventState.runningId != DBConstants.defaultId) {
      return eventState.runningId;
    }
    if (eventState.vpnActionState == VpnActionState.connecting ||
        eventState.vpnActionState == VpnActionState.connected) {
      return eventState.pendingConfigId;
    }
    return DBConstants.defaultId;
  }

  static String _nodeName(
    HomePageState homeState,
    AppEventBusState eventState,
  ) {
    if (!_runtimeActive(eventState)) {
      return _displayName(homeState.configName);
    }

    final id = runtimeConfigId(eventState);
    if (id == DBConstants.defaultId || id != homeState.runtimeConfigId) {
      return emptyNodeName;
    }
    return _displayName(homeState.runtimeConfigName);
  }

  static bool _runtimeActive(AppEventBusState eventState) {
    return switch (eventState.vpnActionState) {
      VpnActionState.connecting ||
      VpnActionState.connected ||
      VpnActionState.disconnecting => true,
      VpnActionState.preparing ||
      VpnActionState.waitingForPlatformPermission ||
      VpnActionState.failed => eventState.runningId != DBConstants.defaultId,
      VpnActionState.idle => false,
    };
  }

  static bool _hasActiveCore(AppEventBusState eventState) {
    return switch (eventState.vpnActionState) {
      VpnActionState.connected || VpnActionState.disconnecting => true,
      VpnActionState.preparing ||
      VpnActionState.waitingForPlatformPermission ||
      VpnActionState.connecting ||
      VpnActionState.failed => eventState.runningId != DBConstants.defaultId,
      VpnActionState.idle => false,
    };
  }

  static bool _isDisconnectAction(
    HomePageState homeState,
    AppEventBusState eventState,
    bool direct,
    bool activeCore,
  ) {
    if (!activeCore) {
      return false;
    }
    if (direct) {
      return true;
    }
    return runtimeConfigId(eventState) == homeState.configId;
  }

  static String _connectionActionLabel(
    AppLocalizations localizations,
    HomePageState homeState,
    AppEventBusState eventState,
    bool direct,
    bool activeCore,
  ) {
    if (direct) {
      return activeCore
          ? localizations.homePageActionDisconnect
          : localizations.homePageActionStartDirect;
    }

    final selectedName = _displayName(homeState.configName);
    if (!activeCore) {
      return localizations.homePageActionConnectToNode(selectedName);
    }

    final runtimeId = runtimeConfigId(eventState);
    if (runtimeId == homeState.configId) {
      return localizations.homePageActionDisconnect;
    }
    return localizations.homePageActionSwitchToNode(selectedName);
  }

  static String _displayName(String name) {
    return name.isEmpty ? emptyNodeName : name;
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
    bool direct,
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
      if (direct) {
        return '${localizations.homePageStatusConnected} · '
            '${localizations.homePageTrafficNotProxied}';
      }
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
