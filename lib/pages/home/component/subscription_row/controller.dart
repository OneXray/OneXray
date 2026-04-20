import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/main/url.dart';
import 'package:onexray/pages/mixin/alert.dart';
import 'package:onexray/pages/subscription/edit/params.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/subscription/service.dart';

class SubscriptionRowController {
  Future<void> updateExpanded(
    SubscriptionData subscription,
    VoidCallback expandCallback,
  ) async {
    final db = AppDatabase();
    if (subscription.id == DBConstants.defaultId) {
      await PreferencesKey().saveLocalSubscriptionExpanded(
        !subscription.expanded,
      );
    } else {
      final row = subscription.copyWith(expanded: !subscription.expanded);
      await db.subscriptionDao.updateRow(row);
    }
    expandCallback();
  }

  Future<void> moreAction(
    BuildContext context,
    SubscriptionData data,
    String menuId,
  ) async {
    final id = IconMenuId.fromString(menuId);
    if (id == null) {
      return;
    }
    switch (id) {
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
          context.push(RouterPath.share, extra: params);
        }
        break;
      case IconMenuId.delete:
        await _showDeleteWarning(context, data);
        break;
      case IconMenuId.clean:
        await _showCleanWarning(context, data);
        break;
      case IconMenuId.edit:
        if (context.mounted) {
          final params = SubscriptionEditParams(id: data.id);
          context.push(RouterPath.subscriptionEdit, extra: params);
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          AppLocalizations.of(ctx)!.homePageSubscriptionDeleteWarning,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSubscription(data);
            },
            child: Text(AppLocalizations.of(ctx)!.buttonOK),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubscription(SubscriptionData data) async {
    final db = AppDatabase();
    await db.subscriptionDao.deleteRow(data.id);
  }

  Future<void> _showCleanWarning(
    BuildContext context,
    SubscriptionData data,
  ) async {
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
              _deleteUnreachableConfigs(data);
            },
            child: Text(AppLocalizations.of(ctx)!.buttonOK),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUnreachableConfigs(SubscriptionData data) async {
    final db = AppDatabase();
    await db.coreConfigDao.deleteUnreachableRows(data.id);
  }
}
