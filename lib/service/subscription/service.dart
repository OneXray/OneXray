import 'dart:async';

import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/share/protocol.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/auto_update/state.dart';

class SubscriptionService {
  static final SubscriptionService _singleton = SubscriptionService._internal();

  factory SubscriptionService() => _singleton;

  SubscriptionService._internal();

  Future<int> insertSubscription(
    String name,
    String url,
    bool showLoading,
  ) async {
    final eventBus = AppEventBus.instance;
    if (showLoading) {
      eventBus.updateDownloading(true);
    }

    final text = await NetClient().getText(url);
    final rows = await _readConfigs(text);
    var count = 0;
    var subId = DBConstants.defaultId;
    if (rows.isNotEmpty) {
      final db = AppDatabase();
      final row = SubscriptionCompanion.insert(
        name: name,
        url: url,
        timestamp: DateTime.now(),
        count: rows.length,
        expanded: true,
      );
      subId = await db.subscriptionDao.insertRow(row);
      if (subId > DBConstants.defaultId) {
        count = await ConfigWriter.writeRows(rows, subId);
      }
    }
    if (showLoading) {
      eventBus.updateDownloading(false);
    }

    if (count > 0) {
      PingService().schedulePingSubscription(subId);
    }

    return count;
  }

  Future<void> updateSubscription(int id, String name) async {
    final sub = await AppDatabase().subscriptionDao.searchRow(id);
    if (sub != null) {
      final newRow = sub.copyWith(name: name);
      await AppDatabase().subscriptionDao.updateRow(newRow);
    }
  }

  Future<int> refreshSubscription(
    SubscriptionData subscription,
    bool showLoading,
  ) async {
    final eventBus = AppEventBus.instance;
    if (showLoading) {
      eventBus.updateDownloading(true);
    }
    final text = await NetClient().getText(subscription.url);
    final rows = await _readConfigs(text);
    var count = 0;
    if (rows.isNotEmpty) {
      final db = AppDatabase();
      await db.subscriptionDao.deleteConfigs(subscription.id);
      count = await ConfigWriter.writeRows(rows, subscription.id);
      final newRow = subscription.copyWith(
        timestamp: DateTime.now(),
        count: count,
      );
      await db.subscriptionDao.updateRow(newRow);
    }
    if (showLoading) {
      eventBus.updateDownloading(false);
    }
    if (count > 0) {
      PingService().schedulePingSubscription(subscription.id);
    }
    return count;
  }

  Future<List<CoreConfigCompanion>> _readConfigs(String? text) async {
    if (text == null) {
      return [];
    }
    final url = text.trim();
    if (AppShareService().checkAppShare(url)) {
      final result = await AppShareService().parseShareText(
        url,
        skipSubscription: true,
      );
      return result.item1;
    } else {
      return XrayShareReader().parseShareText(url);
    }
  }

  Future<void> refreshAllSubscription({bool updateDownloading = true}) async {
    final eventBus = AppEventBus.instance;
    if (updateDownloading) {
      eventBus.updateDownloading(true);
    }

    final db = AppDatabase();
    final subscriptions = await db.subscriptionDao.allRows;
    for (final subscription in subscriptions) {
      await refreshSubscription(subscription, false);
    }
    if (updateDownloading) {
      eventBus.updateDownloading(false);
    }
  }

  Future<void> refreshOutdatedSubscription({
    AutoUpdateState? autoUpdateState,
    bool updateDownloading = true,
  }) async {
    final eventBus = AppEventBus.instance;
    if (updateDownloading) {
      eventBus.updateDownloading(true);
    }

    final updateState = autoUpdateState ?? AutoUpdateState();
    if (autoUpdateState == null) {
      await updateState.readFromPreferences();
    }
    if (!updateState.enable) {
      if (updateDownloading) {
        eventBus.updateDownloading(false);
      }
      return;
    }
    final interval = updateState.interval.value;
    final subs = await AppDatabase().subscriptionDao.allRows;
    final now = DateTime.now();
    for (final sub in subs) {
      if (now.difference(sub.timestamp).inHours >= interval) {
        await refreshSubscription(sub, false);
      }
    }

    if (updateDownloading) {
      eventBus.updateDownloading(false);
    }
  }
}
