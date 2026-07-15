import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ContextAlert {
  static Future<void> showPermissionDialog(BuildContext context) async {
    final openSettings = await showShadDialog<bool>(
      context: context,
      variant: ShadDialogVariant.alert,
      builder: (ctx) => ShadDialog.alert(
        description: Text(AppLocalizations.of(ctx)!.homePageOpenSettings),
        actions: [
          ShadButton.outline(
            child: Text(AppLocalizations.of(ctx)!.buttonCancel),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ShadButton(
            child: Text(AppLocalizations.of(ctx)!.buttonOK),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await openAppSettings();
    }
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
    await showShadDialog<void>(
      context: context,
      builder: (ctx) => ShadDialog(
        title: Text(title),
        description: Text(content),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppLocalizations.of(ctx)!.buttonOK),
          ),
        ],
      ),
    );
  }

  static void showToast(BuildContext context, String message) {
    ShadToaster.of(context).show(
      ShadToast(title: Text(message), duration: const Duration(seconds: 4)),
    );
  }
}
