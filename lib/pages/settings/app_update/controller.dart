import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/service/settings/app_update/service.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/failure.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdateDialogAction { skip }

class AppUpdateDialogController extends PageCubit<AppUpdateDialogAction?> {
  final AppUpdateInfo updateInfo;

  AppUpdateDialogController(this.updateInfo) : super(null);

  void later(BuildContext context) {
    Navigator.pop(context);
  }

  Future<void> skip(BuildContext context) async {
    if (state != null) return;
    emit(AppUpdateDialogAction.skip);
    try {
      await AppUpdateService().skipVersion(updateInfo);
      AppEventBus.instance.updateAppUpdateInfo(null);
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          appFailureMessage(
            AppLocalizations.of(context)!,
            error,
            operation: AppLocalizations.of(context)!.buttonSaveFailed,
          ),
        );
      }
    } finally {
      emit(null);
    }
  }

  Future<void> update(BuildContext context) async {
    final navigator = Navigator.of(context);
    final feedbackContext = navigator.context;
    final l = AppLocalizations.of(context)!;
    navigator.pop();
    try {
      await AppUpdateService().openUpdate(updateInfo);
    } catch (error) {
      ygLogger("openUpdate error: $error");
      if (feedbackContext.mounted) {
        ContextAlert.showToast(feedbackContext, appFailureMessage(l, error));
      }
    }
  }

  Future<void> openLink(BuildContext context, String? href) async {
    if (href == null || href.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(href);
    if (uri == null) {
      ygLogger("openUpdateLink invalid url: $href");
      ContextAlert.showToast(
        context,
        AppLocalizations.of(context)!.prototypeTemporarilyUnavailable,
      );
      return;
    }
    try {
      if (!await launchUrl(uri)) {
        throw StateError('Could not open release link');
      }
    } catch (error) {
      ygLogger("openUpdateLink error: $error");
      if (context.mounted) {
        ContextAlert.showToast(
          context,
          appFailureMessage(AppLocalizations.of(context)!, error),
        );
      }
    }
  }
}
