import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/home/xray/outbound/params.dart';
import 'package:onexray/pages/home/xray/raw/params.dart';
import 'package:onexray/pages/home/xray/setting/ui/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';

class ConfigRowController {
  Future<void> moreAction(
    BuildContext context,
    CoreConfigData config,
    String menuId,
  ) async {
    final id = IconMenuId.fromString(menuId);
    if (id == null) {
      return;
    }
    final db = AppDatabase();
    switch (id) {
      case IconMenuId.edit:
        _gotoConfig(context, config);
        break;
      case IconMenuId.share:
        if (context.mounted) {
          final params = SharePageParams(ShareType.config, config.id);
          context.push(RouterPath.share, extra: params);
        }
        break;
      case IconMenuId.copy:
        await db.coreConfigDao.copyRow(config.id);
        break;
      case IconMenuId.delete:
        await db.coreConfigDao.deleteRow(config);
        break;
      default:
        break;
    }
  }

  void _gotoConfig(BuildContext context, CoreConfigData config) {
    final type = CoreConfigType.fromString(config.type);
    if (type == null) {
      return;
    }
    switch (type) {
      case CoreConfigType.outbound:
        final params = OutboundUIParams(config.id, OutboundState(), []);
        context.push(RouterPath.outboundUI, extra: params);
        break;
      case CoreConfigType.raw:
        final params = XrayRawParams(config.id);
        context.push(RouterPath.xrayRaw, extra: params);
        break;
      case CoreConfigType.setting:
        if (config.id == XraySettingSimple.simpleId) {
          context.push(RouterPath.xraySettingSimple);
        } else {
          final params = XraySettingUIParams(config.id);
          context.push(RouterPath.xraySettingUI, extra: params);
        }
        break;
    }
  }
}
