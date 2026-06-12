import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/network/model.dart';
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
import 'package:onexray/service/share/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/vpn/service.dart';
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
  var _systemExtensionApprovalShown = false;

  Future<void> _asyncInit() async {
    _initToastStream();
    _initRefreshVpnStream();
    final pendingRefreshVpnResult = AppFlutterApi().consumeRefreshVpnResult();
    if (pendingRefreshVpnResult != null) {
      _handleRefreshVpn(pendingRefreshVpnResult);
    }
    BackgroundTaskService().init();
    unawaited(VpnService().refreshVpnStatus());
    final id = await PreferencesKey().readLastConfigId();
    emit(state.copyWith(configId: id));
    await _updateConfigName(id);
    unawaited(_checkAppUpdate());
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
    if (AppPlatform.isMacOS && useSystemExtension) {
      if (result != RefreshVpnResult.waitForApproval) {
        _systemExtensionApprovalShown = false;
        return;
      }
      if (_systemExtensionApprovalShown || !context.mounted) {
        return;
      }
      _systemExtensionApprovalShown = true;
      ygLogger("VPN is waiting for approval, showing alert dialog");
      ContextAlert.showOKDialog(
        context,
        "System Extension Approval",
        "VPN is waiting for approval, showing alert dialog",
      );
    }
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

  String formatGeoLocation(BuildContext context, GeoLocation location) {
    var text = "";
    text += AppLocalizations.of(context)!.nodeInfoPageDuration;
    if (location.duration == null) {
      text += ": ${AppLocalizations.of(context)!.nodeInfoPageFetching} ";
    } else {
      text += ": ${location.duration} ";
    }
    text += AppLocalizations.of(context)!.nodeInfoPageDelay;
    if (location.delay == null) {
      text += ": ${AppLocalizations.of(context)!.nodeInfoPageFetching} ";
    } else {
      text += ": ${location.delay}ms ";
    }
    text += AppLocalizations.of(context)!.nodeInfoPageLocation;
    if (location.country == null) {
      text += ": ${AppLocalizations.of(context)!.nodeInfoPageFetching} ";
    } else {
      text += ": ${location.country} ";
    }
    return text;
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

    final permission = await VpnService().checkPermission();
    if (!permission) {
      if (context.mounted) {
        ContextAlert.showPermissionDialog(context);
      }
      return;
    }
    await VpnService().startVpn(state.configId);
  }

  @override
  Future<void> close() {
    _toastSubscription.cancel();
    _refreshVpnSubscription.cancel();
    return super.close();
  }
}
