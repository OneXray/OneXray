import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';

class OutboundSelectController {
  Future<void> select(BuildContext context, CoreConfigData config) async {
    final outbound = await AppDatabase().coreConfigDao.searchRow(config.id);
    if (!context.mounted) {
      return;
    }
    if (outbound == null) {
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.vpnOutboundInvalid,
      );
      return;
    }
    context.pop(outbound);
  }
}
