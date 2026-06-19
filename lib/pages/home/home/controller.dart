import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/app_update/dialog.dart';
import 'package:onexray/pages/home/xray/outbound/params.dart';
import 'package:onexray/pages/home/xray/raw/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/background_task/service.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/geo_data/system_dat_service.dart';
import 'package:onexray/service/share/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/metrics/formatter.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeState {
  final int configId;
  final String configName;

  const HomeState({required this.configId, required this.configName});

  factory HomeState.initial() =>
      const HomeState(configId: DBConstants.defaultId, configName: "");

  HomeState copyWith({int? configId, String? configName}) {
    return HomeState(
      configId: configId ?? this.configId,
      configName: configName ?? this.configName,
    );
  }
}

class HomeController extends Cubit<HomeState> {
  final BuildContext context;
  final TabController tabController;

  HomeController(this.context, this.tabController)
    : super(HomeState.initial()) {
    _asyncInit();
  }

  late final StreamSubscription<void> _toastSubscription;
  late final StreamSubscription<RefreshVpnResult> _refreshVpnSubscription;
  Future<void>? _systemGeoDatFuture;
  Timer? _systemExtensionApprovalPollTimer;
  var _systemExtensionApprovalShown = false;
  var _systemExtensionApprovalRefreshInFlight = false;

  Future<void> _asyncInit() async {
    _initToastStream();
    _initRefreshVpnStream();
    final pendingRefreshVpnResult = AppFlutterApi().consumeRefreshVpnResult();
    if (pendingRefreshVpnResult != null) {
      _handleRefreshVpn(pendingRefreshVpnResult);
    }
    _systemGeoDatFuture = _checkSystemGeoDatAssets();
    unawaited(_systemGeoDatFuture!);
    unawaited(_initServices());
    try {
      final id = await PreferencesKey().readLastConfigId();
      if (isClosed) {
        return;
      }
      emit(state.copyWith(configId: id));
      await _updateConfigName(id);
    } catch (e, stackTrace) {
      ygLogger("home init error: $e\n$stackTrace");
    }
    unawaited(_checkAppUpdate());
  }

  Future<void> _initServices() async {
    try {
      if (isClosed || !context.mounted) {
        return;
      }
      await context.read<AppEventBus>().asyncInitService(context);
    } catch (e, stackTrace) {
      ygLogger("home service init error: $e\n$stackTrace");
    }

    if (isClosed) {
      return;
    }
    try {
      BackgroundTaskService().init();
    } catch (e, stackTrace) {
      ygLogger("background task init error: $e\n$stackTrace");
    }
    unawaited(_refreshVpnStatus());
  }

  Future<void> _refreshVpnStatus() async {
    try {
      await VpnService().refreshVpnStatus();
    } catch (e, stackTrace) {
      ygLogger("refreshVpnStatus error: $e\n$stackTrace");
    }
  }

  Future<void> _checkSystemGeoDatAssets() async {
    try {
      await SystemGeoDatService().checkAssets();
    } catch (e, stackTrace) {
      ygLogger("checkSystemGeoDatAssets error: $e\n$stackTrace");
    }
  }

  Future<void> _ensureSystemGeoDatAssets() async {
    final systemGeoDatFuture = _systemGeoDatFuture ??=
        _checkSystemGeoDatAssets();
    await systemGeoDatFuture;
  }

  Future<void> _checkAppUpdate() async {
    try {
      await Future.delayed(const Duration(seconds: 3));
      if (isClosed || !context.mounted) {
        return;
      }
      if (!await PreferencesKey().readPrivacyAccepted()) {
        return;
      }
      final service = AppUpdateService();
      if (!await service.shouldRunAutomaticCheck()) {
        return;
      }
      await service.recordAutomaticCheck();
      final result = await service.checkForUpdate();
      if (isClosed ||
          !context.mounted ||
          result.status != AppUpdateCheckStatus.available ||
          result.updateInfo == null) {
        return;
      }
      final updateInfo = result.updateInfo!;
      if (!await service.shouldShowAutomaticReminder(updateInfo)) {
        return;
      }
      if (!isClosed && context.mounted) {
        await AppUpdateDialog.show(context, updateInfo);
      }
    } catch (e) {
      ygLogger("checkAppUpdate error: $e");
    }
  }

  void _initToastStream() {
    _toastSubscription = ToastService().toastBroadcast.stream.listen(
      (message) => _showToast(message),
    );
  }

  void _showToast(String message) {
    if (context.mounted) {
      ContextAlert.showToast(context, message);
    }
  }

  void _initRefreshVpnStream() {
    _refreshVpnSubscription = AppFlutterApi().refreshVpnController.stream
        .listen((result) => _handleRefreshVpn(result));
  }

  void _handleRefreshVpn(RefreshVpnResult result) async {
    final useSystemExtension = await AppHostApi().useSystemExtension();
    if (!context.mounted || isClosed) {
      return;
    }
    if (AppPlatform.isMacOS && useSystemExtension) {
      final permission = _macosPermissionFromRefresh(result);
      final eventBus = context.read<AppEventBus>();
      eventBus.updatePlatformPermission(permission);
      if (result != RefreshVpnResult.waitForApproval) {
        _stopSystemExtensionApprovalPolling();
        _systemExtensionApprovalShown = false;
        if (eventBus.state.vpnActionState ==
            VpnActionState.waitingForPlatformPermission) {
          eventBus.updateVpnActionState(VpnActionState.idle);
        }
        return;
      }
      _startSystemExtensionApprovalPolling();
      eventBus.updateVpnActionState(
        VpnActionState.waitingForPlatformPermission,
      );
      if (_systemExtensionApprovalShown || !context.mounted) {
        return;
      }
      _systemExtensionApprovalShown = true;
      ygLogger("VPN is waiting for approval, showing alert dialog");
      unawaited(_showSystemExtensionApprovalDialog());
    }
  }

  void _startSystemExtensionApprovalPolling() {
    if (_systemExtensionApprovalPollTimer != null) {
      return;
    }
    _systemExtensionApprovalPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        if (isClosed || !context.mounted) {
          _stopSystemExtensionApprovalPolling();
          return;
        }
        if (_systemExtensionApprovalRefreshInFlight) {
          return;
        }
        _systemExtensionApprovalRefreshInFlight = true;
        unawaited(
          _refreshVpnStatus().whenComplete(() {
            _systemExtensionApprovalRefreshInFlight = false;
          }),
        );
      },
    );
  }

  void _stopSystemExtensionApprovalPolling() {
    _systemExtensionApprovalPollTimer?.cancel();
    _systemExtensionApprovalPollTimer = null;
  }

  PlatformPermissionResult _macosPermissionFromRefresh(
    RefreshVpnResult result,
  ) {
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

  Future<void> _showSystemExtensionApprovalDialog() async {
    if (!context.mounted) {
      return;
    }
    await ContextAlert.showOKDialog(
      context,
      AppLocalizations.of(context)!.homePageWaitForApprovalTitle,
      AppLocalizations.of(context)!.homePageWaitForApprovalTips,
    );
  }

  void gotoSettings(BuildContext context) {
    context.push(RouterPath.setting);
  }

  Future<void> addMenuAction(BuildContext context, String menuId) async {
    final id = IconMenuId.fromString(menuId);
    if (id == null) {
      return;
    }
    switch (id) {
      case IconMenuId.manualInput:
        _addConfig(context);
        break;
      case IconMenuId.subscribeLink:
        _addSubscription(context);
        break;
      case IconMenuId.scanQRCode:
        await _scanQrCode(context);
        break;
      case IconMenuId.pickImage:
        await ShareService().pickImage();
        break;
      case IconMenuId.pickFile:
        await ShareService().pickFile();
        break;
      case IconMenuId.readPasteboard:
        await ShareService().readPasteboard();
        break;
      default:
        break;
    }
  }

  void _addConfig(BuildContext context) {
    switch (tabController.index) {
      case 0:
        final params = OutboundUIParams(
          DBConstants.defaultId,
          OutboundState(),
          [],
        );
        context.push(RouterPath.outboundUI, extra: params);
        break;
      case 1:
        final params = XrayRawParams(DBConstants.defaultId);
        context.push(RouterPath.xrayRaw, extra: params);
        break;
    }
  }

  void _addSubscription(BuildContext context) {
    context.push(RouterPath.subscriptionAdd);
  }

  Future<void> _scanQrCode(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (context.mounted) {
        final result = await context.push<String>(RouterPath.qrcode);
        if (result != null) {
          await ShareService().readShareText(result);
        }
      }
    } else {
      if (context.mounted) {
        await ContextAlert.showPermissionDialog(context);
      }
    }
  }

  String formatGeoLocation(BuildContext context, AppEventBusState eventState) {
    final location = eventState.location;
    final appLocalizations = AppLocalizations.of(context)!;
    var text = "";
    text += appLocalizations.nodeInfoPageDuration;
    text += ": ${location.duration ?? appLocalizations.nodeInfoPageFetching} ";
    text += appLocalizations.nodeInfoPageDelay;
    text += ": ${_formatDelay(context, eventState)} ";
    text += appLocalizations.nodeInfoPageLocation;
    text += ": ${_formatGeoValue(context, eventState, location.country)} ";
    return text;
  }

  String formatTraffic(AppEventBusState eventState) {
    return XrayMetricsFormatter.formatTraffic(eventState.trafficMetrics);
  }

  String _formatDelay(BuildContext context, AppEventBusState eventState) {
    final appLocalizations = AppLocalizations.of(context)!;
    switch (eventState.pingProbeState) {
      case ConnectivityProbeState.idle:
      case ConnectivityProbeState.loading:
        return appLocalizations.nodeInfoPageFetching;
      case ConnectivityProbeState.failed:
        return appLocalizations.nodeInfoPageFailed;
      case ConnectivityProbeState.success:
        final delay = eventState.location.delay;
        return delay == null
            ? appLocalizations.nodeInfoPageFailed
            : "${delay}ms";
    }
  }

  String _formatGeoValue(
    BuildContext context,
    AppEventBusState eventState,
    String? value,
  ) {
    final appLocalizations = AppLocalizations.of(context)!;
    switch (eventState.geoLocationProbeState) {
      case ConnectivityProbeState.idle:
      case ConnectivityProbeState.loading:
        return appLocalizations.nodeInfoPageFetching;
      case ConnectivityProbeState.failed:
        return appLocalizations.nodeInfoPageFailed;
      case ConnectivityProbeState.success:
        return value ?? appLocalizations.nodeInfoPageFailed;
    }
  }

  void gotoNodeInfo(BuildContext context) {
    context.push(RouterPath.nodeInfo);
  }

  Future<void> _updateConfigName(int value) async {
    final configName = await _readConfigName(value);
    if (!isClosed && state.configId == value) {
      emit(state.copyWith(configName: configName));
    }
  }

  Future<String> _readConfigName(int id) async {
    if (id == DBConstants.defaultId) {
      return "";
    }
    final config = await AppDatabase().coreConfigDao.searchRow(id);
    return config?.name ?? "";
  }

  void updateConfigId(BuildContext context, int value) {
    emit(state.copyWith(configId: value, configName: ""));
    unawaited(_updateConfigName(value));
  }

  Future<void> startVpn(BuildContext context) async {
    if (state.configId == DBConstants.defaultId) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.vpnSelectOneConfig,
      );
      return;
    }

    await _ensureSystemGeoDatAssets();
    final result = await VpnService().startVpn(state.configId);
    await _handleVpnCommandResult(result);
  }

  Future<void> _handleVpnCommandResult(NativeVpnCommandResult result) async {
    if (!context.mounted) {
      return;
    }
    switch (result.state) {
      case NativeVpnCommandState.success:
        return;
      case NativeVpnCommandState.waitingForPlatformPermission:
        final permission = result.permission;
        if (permission?.kind == PlatformPermissionKind.macosSystemExtension) {
          _startSystemExtensionApprovalPolling();
          _systemExtensionApprovalShown = true;
          await _showSystemExtensionApprovalDialog();
          return;
        }
        if (permission?.kind == PlatformPermissionKind.androidVpn &&
            permission?.state == PlatformPermissionState.denied) {
          await ContextAlert.showPermissionDialog(context);
        }
        return;
      case NativeVpnCommandState.failed:
        final message = result.message;
        if (message != null && message.isNotEmpty) {
          ContextAlert.showToast(context, message);
        }
        return;
    }
  }

  @override
  Future<void> close() {
    _toastSubscription.cancel();
    _refreshVpnSubscription.cancel();
    _stopSystemExtensionApprovalPolling();
    return super.close();
  }
}
