import 'package:flutter/material.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/service/app_update/service.dart';

class AppUpdateDialog {
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo updateInfo,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.appUpdateDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${localizations.appUpdateCurrentVersion}: ${updateInfo.currentVersion}",
              ),
              Text(
                "${localizations.appUpdateLatestVersion}: ${updateInfo.latestVersion}",
              ),
              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(updateInfo.releaseNotes),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppUpdateService().skipVersion(updateInfo);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: Text(localizations.appUpdateSkipVersion),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(localizations.appUpdateLater),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AppUpdateService().openUpdate(updateInfo);
              } catch (e) {
                ygLogger("openUpdate error: $e");
              }
            },
            child: Text(localizations.appUpdateOpen),
          ),
        ],
      ),
    );
  }
}
