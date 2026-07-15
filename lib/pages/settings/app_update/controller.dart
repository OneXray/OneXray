import 'package:flutter/material.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/app_update/service.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateDialogController {
  final AppUpdateInfo updateInfo;

  const AppUpdateDialogController(this.updateInfo);

  void later(BuildContext context) {
    Navigator.pop(context);
  }

  Future<void> skip(BuildContext context) async {
    await AppUpdateService().skipVersion(updateInfo);
    AppEventBus.instance.updateAppUpdateInfo(null);
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> update(BuildContext context) async {
    Navigator.pop(context);
    try {
      await AppUpdateService().openUpdate(updateInfo);
    } catch (error) {
      ygLogger("openUpdate error: $error");
    }
  }

  Future<void> openLink(String? href) async {
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
    } catch (error) {
      ygLogger("openUpdateLink error: $error");
    }
  }
}
