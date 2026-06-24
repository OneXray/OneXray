import 'package:flutter/material.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/core/xray/outbound/params.dart';
import 'package:onexray/pages/core/xray/raw/params.dart';
import 'package:onexray/pages/core/xray/setting/ui/params.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/setting/simple_state.dart';
import 'package:onexray/pages/main/navigation.dart';

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
          context.pushScoped(AppSecondaryDestination.share, extra: params);
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
        context.pushScoped(AppSecondaryDestination.outboundUI, extra: params);
        break;
      case CoreConfigType.raw:
        final params = XrayRawParams(config.id);
        context.pushScoped(AppSecondaryDestination.xrayRaw, extra: params);
        break;
      case CoreConfigType.setting:
        if (config.id == XraySettingSimple.simpleId) {
          context.pushScoped(AppSecondaryDestination.xraySettingSimple);
        } else {
          final params = XraySettingUIParams(config.id);
          context.pushScoped(
            AppSecondaryDestination.xraySettingUI,
            extra: params,
          );
        }
        break;
    }
  }
}
