import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/network/model.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/xray/outbound/params.dart';
import 'package:onexray/pages/home/xray/raw/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/background_task/service.dart';
import 'package:onexray/service/share/service.dart';
import 'package:onexray/service/toast/service.dart';
import 'package:onexray/service/vpn/service.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeState {
  final int configId;

  const HomeState({required this.configId});

  factory HomeState.initial() =>
      const HomeState(configId: DBConstants.defaultId);

  HomeState copyWith({int? configId}) {
    return HomeState(configId: configId ?? this.configId);
  }
}

class HomeController extends Cubit<HomeState> {
  final BuildContext context;
  final TabController tabController;

  HomeController(this.context, this.tabController) : super(HomeState.initial()) {
    _asyncInit();
  }

  late final StreamSubscription<void> _toastSubscription;

  Future<void> _asyncInit() async {
    _initToastStream();
    final id = await PreferencesKey().readLastConfigId();
    emit(state.copyWith(configId: id));
    await BackgroundTaskService().checkSubscriptionUpdate();
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

  void updateConfigId(BuildContext context, int value) {
    emit(state.copyWith(configId: value));
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
    return super.close();
  }
}
