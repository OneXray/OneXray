import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/pages/core/xray/full_config/params.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/core/xray/raw/params.dart';
import 'package:onexray/pages/main/navigation.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/service/share/service.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:permission_handler/permission_handler.dart';

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

final class HomeActions {
  final BuildContext context;

  const HomeActions(this.context);

  void gotoXrayProfile() {
    context.goScoped(AppSecondaryDestination.xray);
  }

  void gotoNodeInfo() {
    context.goScoped(AppSecondaryDestination.nodeInfo);
  }

  Future<void> addMenuAction(HomeAddMenuAction action) async {
    switch (action) {
      case HomeAddMenuAction.manualOutbound:
        _addOutboundConfig();
      case HomeAddMenuAction.manualRaw:
        _addRawConfig();
      case HomeAddMenuAction.manualFull:
        _addFullConfig();
      case HomeAddMenuAction.subscribeLink:
        _addSubscription();
      case HomeAddMenuAction.scanQRCode:
        await _scanQrCode();
      case HomeAddMenuAction.pickImage:
        await ShareService().pickImage();
      case HomeAddMenuAction.pickFile:
        await ShareService().pickFile();
      case HomeAddMenuAction.readPasteboard:
        await ShareService().readPasteboard();
    }
  }

  void _addOutboundConfig() {
    final params = OutboundUIParams(DBConstants.defaultId, OutboundState(), []);
    context.pushScoped(AppSecondaryDestination.outboundUI, extra: params);
  }

  void _addRawConfig() {
    final params = XrayRawParams(DBConstants.defaultId);
    context.pushScoped(AppSecondaryDestination.xrayRaw, extra: params);
  }

  void _addFullConfig() {
    final params = XrayFullConfigParams(DBConstants.defaultId);
    context.pushScoped(AppSecondaryDestination.xrayFullConfig, extra: params);
  }

  void _addSubscription() {
    context.pushScoped(AppSecondaryDestination.subscriptionAdd);
  }

  Future<void> _scanQrCode() async {
    final status = await Permission.camera.request();
    if (!context.mounted) {
      return;
    }
    if (!status.isGranted) {
      await ContextAlert.showPermissionDialog(context);
      return;
    }
    final result = await context.pushScoped<String>(
      AppSecondaryDestination.qrcode,
    );
    if (result != null) {
      await ShareService().readShareText(result);
    }
  }
}
