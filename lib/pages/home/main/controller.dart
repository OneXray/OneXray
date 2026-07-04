import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/pigeon/flutter_api.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/pigeon/messages.g.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/geo_data/list/params.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/core/xray/full_config/params.dart';
import 'package:onexray/pages/core/xray/raw/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/background_task/service.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:onexray/service/geo_data/system_dat_service.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/share/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/metrics/formatter.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/profile/simple_state.dart';
import 'package:permission_handler/permission_handler.dart';

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
        configName: "",
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
      return appLocalizationsNoContext().xrayProfileListPageSimple;
    case XrayProfileSimple.simpleId:
      return appLocalizationsNoContext().xrayProfileListPageSimple;
    default:
      return "";
  }
}

enum HomeConnectionTone {
  disconnected,
  connecting,
  connected,
  waitingForApproval,
  failed,
}

enum HomeAddMenuAction {
  manualOutbound,
  manualRaw,
  manualFull,
  subscribeLink,
  scanQRCode,
  pickImage,
  pickFile,
  readPasteboard,
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

class HomeController extends Cubit<HomePageState> {
  final BuildContext context;

  HomeController(this.context)
    : super(
        HomePageState.initial(
          xrayProfileId: AppEventBus.instance.state.xrayProfileId,
        ),
      ) {
    _asyncInit();
  }

  late final StreamSubscription<void> _toastSubscription;
  late final StreamSubscription<RefreshVpnResult> _refreshVpnSubscription;
  StreamSubscription<int>? _xrayProfileSubscription;
  Future<void>? _systemGeoDatFuture;
  Timer? _systemExtensionApprovalPollTimer;
  var _systemExtensionApprovalShown = false;
  var _systemExtensionApprovalRefreshInFlight = false;

  Future<void> _asyncInit() async {
    _initToastStream();
    _initRefreshVpnStream();
    unawaited(_listenXrayProfile());
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
        await context.pushAppUpdateDialog(updateInfo);
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

  Future<void> _listenXrayProfile() async {
    final eventBus = AppEventBus.instance;
    var xrayProfileId = eventBus.state.xrayProfileId;
    xrayProfileId = await PreferencesKey().readXrayProfileId();
    if (isClosed) {
      return;
    }
    await _readXrayProfile(xrayProfileId);

    _xrayProfileSubscription = eventBus.stream
        .map((s) => s.xrayProfileId)
        .distinct()
        .listen((data) => _readXrayProfile(data));
  }

  Future<void> _readXrayProfile(int id) async {
    if (isClosed) {
      return;
    }
    switch (id) {
      case DBConstants.defaultId:
        emit(
          state.copyWith(
            xrayProfileName:
                appLocalizationsNoContext().xrayProfileListPageSimple,
          ),
        );
        break;
      case XrayProfileSimple.simpleId:
        emit(
          state.copyWith(
            xrayProfileName:
                appLocalizationsNoContext().xrayProfileListPageSimple,
          ),
        );
        break;
      default:
        final xrayProfileData = await AppDatabase().coreConfigDao.searchRow(id);
        if (isClosed) {
          return;
        }
        if (xrayProfileData != null) {
          emit(state.copyWith(xrayProfileName: xrayProfileData.name));
        } else {
          emit(
            state.copyWith(
              xrayProfileName:
                  appLocalizationsNoContext().xrayProfileListPageSimple,
            ),
          );
        }
        break;
    }
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

  void gotoTunSettings(BuildContext context) {
    context.goScoped(AppSecondaryDestination.tun);
  }

  void gotoXrayProfile(BuildContext context) {
    context.goScoped(AppSecondaryDestination.xray);
  }

  void gotoGeoData(BuildContext context) {
    final params = GeoDataListParams(
      GeoDataListType.full,
      GeoDatCodesMode.show,
    );
    context.goScoped(AppSecondaryDestination.geoData, extra: params);
  }

  void gotoLog(BuildContext context) {
    context.goScoped(AppSecondaryDestination.logs);
  }

  Future<void> addMenuAction(
    BuildContext context,
    HomeAddMenuAction action,
  ) async {
    switch (action) {
      case HomeAddMenuAction.manualOutbound:
        _addOutboundConfig(context);
        break;
      case HomeAddMenuAction.manualRaw:
        _addRawConfig(context);
        break;
      case HomeAddMenuAction.manualFull:
        _addFullConfig(context);
        break;
      case HomeAddMenuAction.subscribeLink:
        _addSubscription(context);
        break;
      case HomeAddMenuAction.scanQRCode:
        await _scanQrCode(context);
        break;
      case HomeAddMenuAction.pickImage:
        await ShareService().pickImage();
        break;
      case HomeAddMenuAction.pickFile:
        await ShareService().pickFile();
        break;
      case HomeAddMenuAction.readPasteboard:
        await ShareService().readPasteboard();
        break;
    }
  }

  void _addOutboundConfig(BuildContext context) {
    final params = OutboundUIParams(DBConstants.defaultId, OutboundState(), []);
    context.pushScoped(AppSecondaryDestination.outboundUI, extra: params);
  }

  void _addRawConfig(BuildContext context) {
    final params = XrayRawParams(DBConstants.defaultId);
    context.pushScoped(AppSecondaryDestination.xrayRaw, extra: params);
  }

  void _addFullConfig(BuildContext context) {
    final params = XrayFullConfigParams(DBConstants.defaultId);
    context.pushScoped(AppSecondaryDestination.xrayFullConfig, extra: params);
  }

  void _addSubscription(BuildContext context) {
    context.pushScoped(AppSecondaryDestination.subscriptionAdd);
  }

  Future<void> _scanQrCode(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (context.mounted) {
        final result = await context.pushScoped<String>(
          AppSecondaryDestination.qrcode,
        );
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

  String formatSummaryMetrics(
    BuildContext context,
    AppEventBusState eventState,
  ) {
    final location = eventState.location;
    final appLocalizations = AppLocalizations.of(context)!;
    final duration = location.duration ?? appLocalizations.nodeInfoPageFetching;
    final country = _formatGeoValue(context, eventState, location.country);
    final delay = _formatDelay(context, eventState);
    return "$duration · $country · $delay";
  }

  String formatTraffic(AppEventBusState eventState) {
    return XrayMetricsFormatter.formatTraffic(eventState.trafficMetrics);
  }

  HomeConnectionViewPageState buildConnectionViewState(
    BuildContext context,
    HomePageState homeState,
    AppEventBusState eventState,
  ) {
    final appLocalizations = AppLocalizations.of(context)!;
    final connected = eventState.runningId != DBConstants.defaultId;
    final waitingForMacApproval = _isWaitingForMacApproval(eventState);
    final failed = eventState.vpnActionState == VpnActionState.failed;
    final nodeName = homeState.configName.isEmpty
        ? appLocalizations.homePageNoSelectedNode
        : homeState.configName;
    final tone = _connectionTone(
      eventState,
      connected,
      waitingForMacApproval,
      failed,
    );
    final statusText = _connectionStatusText(
      appLocalizations,
      eventState,
      connected,
      waitingForMacApproval,
      failed,
    );
    final detailText = failed && eventState.vpnErrorMessage.isNotEmpty
        ? eventState.vpnErrorMessage
        : waitingForMacApproval
        ? appLocalizations.homePageWaitForApprovalTips
        : connected
        ? formatGeoLocation(context, eventState)
        : "${appLocalizations.homePageCurrentNode}: $nodeName";
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
      trafficText: formatTraffic(eventState),
      metricsText: formatSummaryMetrics(context, eventState),
      statusIcon: actionIcon,
      actionIcon: actionIcon,
    );
  }

  HomeConnectionTone _connectionTone(
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

  String _connectionStatusText(
    AppLocalizations appLocalizations,
    AppEventBusState eventState,
    bool connected,
    bool waitingForMacApproval,
    bool failed,
  ) {
    if (waitingForMacApproval) {
      return appLocalizations.homePageWaitForApprovalTitle;
    }
    if (failed) {
      return appLocalizations.nodeInfoPageFailed;
    }
    if (eventState.vpnActionState == VpnActionState.disconnecting) {
      return appLocalizations.homePageStatusDisconnecting;
    }
    if (eventState.vpnLoading) {
      return appLocalizations.homePageStatusConnecting;
    }
    if (connected) {
      return appLocalizations.homePageStatusConnected;
    }
    return appLocalizations.homePageStatusDisconnected;
  }

  bool _isWaitingForMacApproval(AppEventBusState eventState) {
    return eventState.platformPermissionKind ==
            PlatformPermissionKind.macosSystemExtension &&
        eventState.platformPermissionState ==
            PlatformPermissionState.awaitingUserApproval;
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
    context.goScoped(AppSecondaryDestination.nodeInfo);
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

  void toggleNodeSearch() {
    emit(state.copyWith(nodeSearchVisible: !state.nodeSearchVisible));
  }

  Future<void> startVpn(BuildContext context) async {
    if (state.vpnCommandLoading || AppEventBus.instance.state.vpnLoading) {
      return;
    }
    if (state.configId == DBConstants.defaultId) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.vpnSelectOneConfig,
      );
      return;
    }

    emit(state.copyWith(vpnCommandLoading: true));
    try {
      await _ensureSystemGeoDatAssets();
      final result = await VpnService().startVpn(state.configId);
      await _handleVpnCommandResult(result);
    } finally {
      if (!isClosed) {
        emit(state.copyWith(vpnCommandLoading: false));
      }
    }
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
    _xrayProfileSubscription?.cancel();
    _stopSystemExtensionApprovalPolling();
    return super.close();
  }
}
