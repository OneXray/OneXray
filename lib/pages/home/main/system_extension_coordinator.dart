import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';

final class HomeSystemExtensionCoordinator {
  final BuildContext context;
  final Future<void> Function() refreshVpnStatus;

  HomeSystemExtensionCoordinator({
    required this.context,
    required this.refreshVpnStatus,
  });

  StreamSubscription<RefreshVpnResult>? _subscription;
  Timer? _approvalPollTimer;
  var _approvalShown = false;
  var _approvalRefreshInFlight = false;
  var _closed = false;

  void start() {
    if (_closed || _subscription != null) {
      return;
    }
    _subscription = AppFlutterApi().refreshVpnController.stream.listen(
      (result) => unawaited(_handleRefresh(result)),
    );
    final pending = AppFlutterApi().consumeRefreshVpnResult();
    if (pending != null) {
      unawaited(_handleRefresh(pending));
    }
  }

  Future<bool> handleStartPermission(
    PlatformPermissionResult? permission,
  ) async {
    if (permission?.kind != PlatformPermissionKind.macosSystemExtension) {
      return false;
    }
    _startApprovalPolling();
    _approvalShown = true;
    await _showApprovalDialog();
    return true;
  }

  Future<void> _handleRefresh(RefreshVpnResult result) async {
    try {
      final useSystemExtension = await AppHostApi().useSystemExtension();
      if (_closed ||
          !context.mounted ||
          !AppPlatform.isMacOS ||
          !useSystemExtension) {
        return;
      }

      final eventBus = context.read<AppEventBus>();
      eventBus.updatePlatformPermission(_permissionFromRefresh(result));
      if (result != RefreshVpnResult.waitForApproval) {
        _stopApprovalPolling();
        _approvalShown = false;
        if (eventBus.state.vpnActionState ==
            VpnActionState.waitingForPlatformPermission) {
          eventBus.updateVpnActionState(VpnActionState.idle);
        }
        return;
      }

      _startApprovalPolling();
      eventBus.updateVpnActionState(
        VpnActionState.waitingForPlatformPermission,
      );
      if (_approvalShown || !context.mounted) {
        return;
      }
      _approvalShown = true;
      ygLogger('VPN is waiting for approval, showing alert dialog');
      await _showApprovalDialog();
    } catch (error, stackTrace) {
      ygReportError(
        error,
        stackTrace,
        reason: 'System Extension refresh handling failed',
      );
    }
  }

  void _startApprovalPolling() {
    if (_approvalPollTimer != null) {
      return;
    }
    _approvalPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_closed || !context.mounted) {
        _stopApprovalPolling();
        return;
      }
      if (_approvalRefreshInFlight) {
        return;
      }
      _approvalRefreshInFlight = true;
      unawaited(
        refreshVpnStatus().whenComplete(() {
          _approvalRefreshInFlight = false;
        }),
      );
    });
  }

  void _stopApprovalPolling() {
    _approvalPollTimer?.cancel();
    _approvalPollTimer = null;
  }

  PlatformPermissionResult _permissionFromRefresh(RefreshVpnResult result) {
    final state = switch (result) {
      RefreshVpnResult.installed => PlatformPermissionState.granted,
      RefreshVpnResult.waitForApproval =>
        PlatformPermissionState.awaitingUserApproval,
      RefreshVpnResult.notInstalled => PlatformPermissionState.notDetermined,
    };
    return PlatformPermissionResult(
      kind: PlatformPermissionKind.macosSystemExtension,
      state: state,
    );
  }

  Future<void> _showApprovalDialog() async {
    if (!context.mounted) {
      return;
    }
    final localizations = AppLocalizations.of(context)!;
    await ContextAlert.showOKDialog(
      context,
      localizations.homePageWaitForApprovalTitle,
      localizations.homePageWaitForApprovalTips,
    );
  }

  Future<void> close() async {
    _closed = true;
    _stopApprovalPolling();
    await _subscription?.cancel();
    _subscription = null;
  }
}
