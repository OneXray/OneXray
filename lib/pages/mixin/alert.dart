import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:permission_handler/permission_handler.dart';

class ContextAlert {
  static Future<void> showPermissionDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppLocalizations.of(context)!.homePageOpenSettings),
        actions: <Widget>[
          TextButton(
            child: Text(AppLocalizations.of(context)!.buttonCancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: Text(AppLocalizations.of(context)!.buttonOK),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  static Future<void> showPingResultDialog(
    BuildContext context,
    int delay,
  ) async {
    final content = PingService().parsePingResponse(delay);
    await showOKDialog(
      context,
      AppLocalizations.of(context)!.outboundPageRealPingResult,
      content,
    );
  }

  static Future<void> showOKDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.buttonOK),
          ),
        ],
      ),
    );
  }

  static void showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
