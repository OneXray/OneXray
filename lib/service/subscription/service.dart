import 'dart:async';

import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:onexray/service/subscription/validator.dart';

class SubscriptionService {
  static final SubscriptionService _singleton = SubscriptionService._internal();

  factory SubscriptionService() => _singleton;

  SubscriptionService._internal();

  Future<bool> addSubscription(
    String url,
    String name,
    bool showLoading,
  ) async {
    final subscriptionName = name.isEmpty ? "anonymous" : name;
    final checked = await SubscriptionValidator.validate(subscriptionName, url);
    if (!checked.item1) {
      return false;
    }
    final count = await insertSubscription(subscriptionName, url, showLoading);
    return count > 0;
  }

  Future<int> insertSubscription(
    String name,
    String url,
    bool showLoading,
  ) async {
    final eventBus = AppEventBus.instance;
    if (showLoading) {
      eventBus.updateDownloading(true);
    }
    var count = 0;
    var subId = DBConstants.defaultId;
    try {
      final text = await NetClient().getText(url);
      final rows = await _readConfigs(text);
      if (rows.isNotEmpty) {
        final db = AppDatabase();
        final result = await db.transaction(() async {
          final row = SubscriptionCompanion.insert(
            name: name,
            url: url,
            timestamp: DateTime.now(),
            count: rows.length,
            expanded: true,
          );
          final nextSubId = await db.subscriptionDao.insertRow(row);
          if (nextSubId <= DBConstants.defaultId) {
            throw StateError('insert subscription failed');
          }
          final writeResult = await ConfigWriter.writeRowsInTransaction(
            db,
            rows,
            nextSubId,
          );
          if (writeResult.count != rows.length) {
            throw StateError('insert subscription configs failed');
          }
          return (subId: nextSubId, count: writeResult.count);
        });
        subId = result.subId;
        count = result.count;
      }
    } finally {
      if (showLoading) {
        eventBus.updateDownloading(false);
      }
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
    var count = 0;
    try {
      final text = await NetClient().getText(subscription.url);
      final rows = await _readConfigs(text);
      if (rows.isNotEmpty) {
        final db = AppDatabase();
        count = await db.transaction(() async {
          await db.subscriptionDao.deleteConfigs(subscription.id);
          final writeResult = await ConfigWriter.writeRowsInTransaction(
            db,
            rows,
            subscription.id,
          );
          if (writeResult.count != rows.length) {
            throw StateError('replace subscription configs failed');
          }
          final newRow = subscription.copyWith(
            timestamp: DateTime.now(),
            count: writeResult.count,
          );
          if (!await db.subscriptionDao.updateRow(newRow)) {
            throw StateError('update subscription failed');
          }
          return writeResult.count;
        });
      }
    } finally {
      if (showLoading) {
        eventBus.updateDownloading(false);
      }
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
    final rows = await XrayShareReader().parseOutboundShareText(url);
    return rows
        .where(
          (row) =>
              row.type.present &&
              row.type.value == CoreConfigType.outbound.name,
        )
        .toList();
  }

  Future<void> refreshAllSubscription({bool updateDownloading = true}) async {
    final eventBus = AppEventBus.instance;
    if (updateDownloading) {
      eventBus.updateDownloading(true);
    }
    try {
      final db = AppDatabase();
      final subscriptions = await db.subscriptionDao.allRows;
      for (final subscription in subscriptions) {
        await refreshSubscription(subscription, false);
      }
    } finally {
      if (updateDownloading) {
        eventBus.updateDownloading(false);
      }
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
    try {
      final updateState = autoUpdateState ?? AutoUpdateState();
      if (autoUpdateState == null) {
        await updateState.readFromPreferences();
      }
      if (!updateState.subscriptionEnabled) {
        return;
      }
      final interval = updateState.subscriptionInterval.value;
      final subs = await AppDatabase().subscriptionDao.allRows;
      final now = DateTime.now();
      for (final sub in subs) {
        if (now.difference(sub.timestamp).inHours >= interval) {
          await refreshSubscription(sub, false);
        }
      }
    } finally {
      if (updateDownloading) {
        eventBus.updateDownloading(false);
      }
    }
  }
}
