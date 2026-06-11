import 'package:flutter/material.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/pages/app_update/dialog.dart';
import 'package:onexray/service/app_update/service.dart';

class AppUpdateReminder extends StatefulWidget {
  final Widget child;

  const AppUpdateReminder({super.key, required this.child});

  @override
  State<AppUpdateReminder> createState() => _AppUpdateReminderState();
}

class _AppUpdateReminderState extends State<AppUpdateReminder> {
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _checkUpdate();
    }
  }

  Future<void> _checkUpdate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) {
      return;
    }
    if (!await PreferencesKey().readPrivacyAccepted()) {
      return;
    }
    final service = AppUpdateService();
    if (!await service.shouldRunAutomaticCheck()) {
      return;
    }
    await service.recordAutomaticCheck();
    final result = await service.checkForUpdate();
    if (!mounted ||
        result.status != AppUpdateCheckStatus.available ||
        result.updateInfo == null) {
      return;
    }
    final updateInfo = result.updateInfo!;
    if (!await service.shouldShowAutomaticReminder(updateInfo)) {
      return;
    }
    if (mounted) {
      await AppUpdateDialog.show(context, updateInfo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
