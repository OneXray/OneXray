import 'package:flutter/material.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/subscriptions/edit/params.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/subscription/service.dart';
import 'package:onexray/pages/main/navigation.dart';

class SubscriptionRowController {
  Future<void> updateExpanded(
    SubscriptionData subscription,
    VoidCallback expandCallback,
  ) async {
    if (subscription.id == DBConstants.defaultId) {
      await PreferencesKey().saveLocalSubscriptionExpanded(
        !subscription.expanded,
      );
    } else {
      final row = subscription.copyWith(expanded: !subscription.expanded);
      await DataMaintenance.run(
        () => AppDatabase().subscriptionDao.updateRow(row),
      );
    }
    expandCallback();
  }

  Future<void> moreAction(
    BuildContext context,
    SubscriptionData data,
    IconMenuId menuId, {
    Future<void> Function(SubscriptionData data)? cleanCallback,
  }) async {
    switch (menuId) {
      case IconMenuId.refresh:
        final eventBus = AppEventBus.instance;
        if (eventBus.state.downloading) {
          ContextAlert.showToast(
            context,
            AppLocalizations.of(context)!.runningAndWait,
          );
          return;
        }
        await SubscriptionService().refreshSubscription(data, true);
        break;
      case IconMenuId.share:
        if (context.mounted) {
          final params = SharePageParams(ShareType.subscription, data.id);
          context.pushScoped(AppSecondaryDestination.share, extra: params);
        }
        break;
      case IconMenuId.delete:
        await _showDeleteWarning(context, data);
        break;
      case IconMenuId.clean:
        await _showCleanWarning(context, data, cleanCallback: cleanCallback);
        break;
      case IconMenuId.edit:
        if (context.mounted) {
          final params = SubscriptionEditParams(id: data.id);
          context.pushScoped(
            AppSecondaryDestination.subscriptionEdit,
            extra: params,
          );
        }
        break;
      default:
        break;
    }
  }

  Future<void> _showDeleteWarning(
    BuildContext context,
    SubscriptionData data,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppLocalizations.of(ctx)!.homePageSubscriptionDeleteWarning,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.buttonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.buttonOK),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _deleteSubscription(context, data);
    }
  }

  Future<void> _deleteSubscription(
    BuildContext context,
    SubscriptionData data,
  ) async {
    final db = AppDatabase();
    final service = SubscriptionService();
    await service.deleteSubscription(
      data.id,
      prepareDeletion: (subscription) async {
        final references = await service.referenceReader();
        for (final id in references.protectedIds) {
          final config = await db.coreConfigDao.searchRow(id);
          if (config?.subId == subscription.id) {
            if (context.mounted) {
              ContextAlert.showToast(
                context,
                AppLocalizations.of(context)!.validationOutboundInUse,
              );
            }
            return false;
          }
        }
        return true;
      },
    );
  }

  Future<void> _showCleanWarning(
    BuildContext context,
    SubscriptionData data, {
    Future<void> Function(SubscriptionData data)? cleanCallback,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.homePageSubscriptionCleanWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUnreachableConfigs(data, cleanCallback: cleanCallback);
            },
            child: Text(AppLocalizations.of(ctx)!.buttonOK),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUnreachableConfigs(
    SubscriptionData data, {
    Future<void> Function(SubscriptionData data)? cleanCallback,
  }) async {
    if (cleanCallback != null) {
      await cleanCallback(data);
      return;
    }
    await DataMaintenance.run(
      () => AppDatabase().coreConfigDao.deleteUnreachableOutboundRows(data.id),
    );
  }
}
