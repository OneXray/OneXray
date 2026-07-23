import 'dart:async';

import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/validator.dart';

typedef _SubscriptionInsertResult = ({int subId, int count});

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

  Future<int> importSubscriptions(List<SubscriptionImportEntry> entries) async {
    var imported = 0;
    final importedSubIds = <int>[];
    for (final entry in entries) {
      final name = entry.name.isEmpty ? "anonymous" : entry.name;
      try {
        final checked = await SubscriptionValidator.validate(name, entry.url);
        if (!checked.item1) {
          continue;
        }
        final result = await _insertSubscription(name, entry.url);
        if (result.count > 0) {
          imported += 1;
          importedSubIds.add(result.subId);
        }
      } catch (error, stackTrace) {
        ygLogger('import subscription failed: $error\n$stackTrace');
      }
    }
    // A bulk import can contain thousands of nodes. Avoid monopolizing the
    // serialized desktop libXray worker with an automatic ping queue.
    if (entries.length == 1 && importedSubIds.isNotEmpty) {
      PingService().schedulePingSubscriptions(importedSubIds);
    }
    return imported;
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
    var result = (subId: DBConstants.defaultId, count: 0);
    try {
      result = await _insertSubscription(name, url);
    } finally {
      if (showLoading) {
        eventBus.updateDownloading(false);
      }
    }

    if (result.count > 0) {
      PingService().schedulePingSubscription(result.subId);
    }

    return result.count;
  }

  Future<_SubscriptionInsertResult> _insertSubscription(
    String name,
    String url,
  ) async {
    final text = await NetClient().getText(url);
    final rows = await _readConfigs(text);
    if (rows.isEmpty) {
      return (subId: DBConstants.defaultId, count: 0);
    }

    final db = AppDatabase();
    return db.transaction(() async {
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
      final count = await ConfigWriter.writeRowsBatchInTransaction(
        db,
        rows,
        nextSubId,
      );
      if (count != rows.length) {
        throw StateError('insert subscription configs failed');
      }
      return (subId: nextSubId, count: count);
    });
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
          final writeCount = await ConfigWriter.writeRowsBatchInTransaction(
            db,
            rows,
            subscription.id,
          );
          if (writeCount != rows.length) {
            throw StateError('replace subscription configs failed');
          }
          final newRow = subscription.copyWith(
            timestamp: DateTime.now(),
            count: writeCount,
          );
          if (!await db.subscriptionDao.updateRow(newRow)) {
            throw StateError('update subscription failed');
          }
          return writeCount;
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
