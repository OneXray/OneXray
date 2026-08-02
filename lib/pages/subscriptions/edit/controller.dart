import 'package:flutter/material.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/subscriptions/edit/params.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/service/subscription/validator.dart';

class SubscriptionEditController extends PageCubit<void> {
  final SubscriptionEditParams params;
  SubscriptionEditController(this.params) : super(null) {
    _init();
  }

  final nameController = TextEditingController();
  final urlController = TextEditingController();

  @override
  Future<void> disposePageResources() async {
    nameController.dispose();
    urlController.dispose();
  }

  Future<void> _init() async {
    final sub = await AppDatabase().subscriptionDao.searchRow(params.id);
    if (!isPageActive) {
      return;
    }
    if (sub != null) {
      nameController.text = sub.name;
      urlController.text = sub.url;
    }
  }

  Future<void> save(BuildContext context) async {
    final name = nameController.text.trim();
    final url = SubscriptionUrl.normalize(urlController.text);
    final check = await SubscriptionValidator.validate(
      name,
      url,
      excludingId: params.id,
    );
    if (!context.mounted) {
      return;
    }
    if (!check.item1) {
      ContextAlert.showToast(context, check.item2);
      return;
    }

    final result = await SubscriptionService().updateSubscription(
      params.id,
      name,
      url,
    );
    if (!context.mounted) {
      return;
    }
    switch (result) {
      case SubscriptionUpdateResult.success:
        context.pop();
      case SubscriptionUpdateResult.downloadFailed:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.subscriptionDownloadFailed,
        );
      case SubscriptionUpdateResult.invalidContent:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.subscriptionAddPageNoConfigs,
        );
      case SubscriptionUpdateResult.notFound:
      case SubscriptionUpdateResult.writeFailed:
        ContextAlert.showToast(
          context,
          AppLocalizations.of(context)!.buttonSaveFailed,
        );
    }
  }
}
