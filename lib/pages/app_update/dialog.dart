import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/app_update/params.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppUpdateDialogParams params;

  const AppUpdateDialog({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final updateInfo = params.updateInfo;
    final releaseNotes = updateInfo.releaseNotes.trim();
    final size = MediaQuery.sizeOf(context);
    final maxWidth = size.width * 0.86 < 560.0 ? size.width * 0.86 : 560.0;
    final maxHeight = size.height * 0.58 < 520.0 ? size.height * 0.58 : 520.0;

    return AlertDialog(
      title: Text(localizations.appUpdateDialogTitle),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
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
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Flexible(
                child: Markdown(
                  data: releaseNotes,
                  padding: EdgeInsets.zero,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                  onTapLink: (_, href, _) => _openLink(href),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await AppUpdateService().skipVersion(updateInfo);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: Text(localizations.appUpdateSkipVersion),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.appUpdateLater),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await AppUpdateService().openUpdate(updateInfo);
            } catch (e) {
              ygLogger("openUpdate error: $e");
            }
          },
          child: Text(localizations.appUpdateOpen),
        ),
      ],
    );
  }

  Future<void> _openLink(String? href) async {
    if (href == null || href.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri == null) {
      ygLogger("openUpdateLink invalid url: $href");
      return;
    }
    try {
      await launchUrl(uri);
    } catch (e) {
      ygLogger("openUpdateLink error: $e");
    }
  }
}
