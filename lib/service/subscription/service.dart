import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/network/client.dart';
import 'package:onexray/core/network/model.dart';
import 'package:onexray/core/pigeon/model.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/auto_update/state.dart';
import 'package:onexray/service/db/config_writer.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/validator.dart';

typedef _SubscriptionLoadResult = ({
  SubscriptionUpdateResult status,
  List<CoreConfigCompanion> rows,
});

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
    final result = await insertSubscription(
      SubscriptionInput(name: subscriptionName, url: url),
      showLoading,
    );
    return result.success;
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
        final result = await _insertSubscription(
          SubscriptionInput(name: name, url: entry.url),
        );
        if (result.success) {
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

  Future<SubscriptionInsertResult> insertSubscription(
    SubscriptionInput input,
    bool showLoading,
  ) async {
    final eventBus = AppEventBus.instance;
    if (showLoading) {
      eventBus.updateDownloading(true);
    }
    var result = const SubscriptionInsertResult(
      status: SubscriptionUpdateResult.writeFailed,
    );
    try {
      result = await _insertSubscription(input);
    } finally {
      if (showLoading) {
        eventBus.updateDownloading(false);
      }
    }

    if (result.success) {
      PingService().schedulePingSubscription(result.subId);
    }

    return result;
  }

  Future<SubscriptionInsertResult> _insertSubscription(
    SubscriptionInput input,
  ) async {
    final loaded = await _loadRows(input);
    if (loaded.status != SubscriptionUpdateResult.success) {
      return SubscriptionInsertResult(status: loaded.status);
    }
    final rows = loaded.rows;

    final db = AppDatabase();
    try {
      return await db.transaction(() async {
        final row = SubscriptionCompanion.insert(
          name: input.name,
          url: input.url,
          ageSecretKey: Value(input.normalizedAgeSecretKey),
          agePublicKey: Value(input.normalizedAgePublicKey),
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
        return SubscriptionInsertResult(
          status: SubscriptionUpdateResult.success,
          subId: nextSubId,
          count: count,
        );
      });
    } catch (error, stackTrace) {
      ygLogger(
        'insert subscription failed (${error.runtimeType})\n$stackTrace',
      );
      return const SubscriptionInsertResult(
        status: SubscriptionUpdateResult.writeFailed,
      );
    }
  }

  Future<SubscriptionUpdateResult> updateSubscription(
    int id,
    SubscriptionInput input,
  ) async {
    if (input.hasIncompleteAgeKeyPair) {
      return SubscriptionUpdateResult.invalidAgeSecretKey;
    }
    final db = AppDatabase();
    final subscription = await db.subscriptionDao.searchRow(id);
    if (subscription == null) {
      return SubscriptionUpdateResult.notFound;
    }
    final ageSecretKey = input.normalizedAgeSecretKey;
    final agePublicKey = input.normalizedAgePublicKey;
    if (subscription.url == input.url &&
        subscription.ageSecretKey == ageSecretKey &&
        subscription.agePublicKey == agePublicKey) {
      try {
        final updated = await db.subscriptionDao.updateRow(
          subscription.copyWith(name: input.name),
        );
        return updated
            ? SubscriptionUpdateResult.success
            : SubscriptionUpdateResult.writeFailed;
      } catch (error, stackTrace) {
        ygLogger(
          'update subscription failed (${error.runtimeType})\n$stackTrace',
        );
        return SubscriptionUpdateResult.writeFailed;
      }
    }

    final eventBus = AppEventBus.instance;
    eventBus.updateDownloading(true);
    try {
      final loaded = await _loadRows(input);
      if (loaded.status != SubscriptionUpdateResult.success) {
        return loaded.status;
      }
      final rows = loaded.rows;

      try {
        await db.transaction(() async {
          await db.subscriptionDao.deleteConfigs(subscription.id);
          final count = await ConfigWriter.writeRowsBatchInTransaction(
            db,
            rows,
            subscription.id,
          );
          if (count != rows.length) {
            throw StateError('replace subscription configs failed');
          }
          final updated = subscription.copyWith(
            name: input.name,
            url: input.url,
            ageSecretKey: Value(ageSecretKey),
            agePublicKey: Value(agePublicKey),
            timestamp: DateTime.now(),
            count: count,
          );
          if (!await db.subscriptionDao.updateRow(updated)) {
            throw StateError('update subscription failed');
          }
        });
      } catch (error, stackTrace) {
        ygLogger(
          'replace subscription failed (${error.runtimeType})\n$stackTrace',
        );
        return SubscriptionUpdateResult.writeFailed;
      }

      PingService().schedulePingSubscription(subscription.id);
      return SubscriptionUpdateResult.success;
    } finally {
      eventBus.updateDownloading(false);
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
      final loaded = await _loadRows(
        SubscriptionInput(
          name: subscription.name,
          url: subscription.url,
          ageSecretKey: subscription.ageSecretKey,
          agePublicKey: subscription.agePublicKey,
        ),
      );
      if (loaded.status == SubscriptionUpdateResult.success) {
        final rows = loaded.rows;
        final db = AppDatabase();
        try {
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
        } catch (error, stackTrace) {
          ygLogger(
            'refresh subscription failed (${error.runtimeType})\n$stackTrace',
          );
        }
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

  Future<List<CoreConfigCompanion>> _readConfigs(
    String text, {
    String? ageSecretKey,
  }) async {
    final url = text.trim();
    final rows = await XrayShareReader().parseOutboundShareText(
      url,
      ageSecretKey: ageSecretKey,
    );
    return rows
        .where(
          (row) =>
              row.type.present &&
              row.type.value == CoreConfigType.outbound.name,
        )
        .toList();
  }

  Future<_SubscriptionLoadResult> _loadRows(SubscriptionInput input) async {
    if (input.hasIncompleteAgeKeyPair) {
      return (
        status: SubscriptionUpdateResult.invalidAgeSecretKey,
        rows: <CoreConfigCompanion>[],
      );
    }
    final ageContext = input.normalizedAgeContext;

    final text = await NetClient().getText(
      input.url,
      requestHeaders: DownloadRequestHeaders(
        agePublicKey: ageContext?.publicKey,
      ),
    );
    if (text == null) {
      return (
        status: SubscriptionUpdateResult.downloadFailed,
        rows: <CoreConfigCompanion>[],
      );
    }

    try {
      final rows = await _readConfigs(
        text,
        ageSecretKey: ageContext?.secretKey,
      );
      return (
        status: rows.isEmpty
            ? SubscriptionUpdateResult.invalidContent
            : SubscriptionUpdateResult.success,
        rows: rows,
      );
    } on LibXrayInvokeException catch (error) {
      return (
        status: _ageErrorStatus(error.message),
        rows: <CoreConfigCompanion>[],
      );
    } catch (error, stackTrace) {
      ygLogger('parse subscription failed (${error.runtimeType})\n$stackTrace');
      return (
        status: SubscriptionUpdateResult.invalidContent,
        rows: <CoreConfigCompanion>[],
      );
    }
  }

  SubscriptionUpdateResult _ageErrorStatus(String error) {
    return switch (error) {
      LibXrayErrorMessage.invalidAgeSecretKey =>
        SubscriptionUpdateResult.invalidAgeSecretKey,
      LibXrayErrorMessage.missingAgeSecretKey =>
        SubscriptionUpdateResult.missingAgeSecretKey,
      LibXrayErrorMessage.ageDecryptFailed ||
      LibXrayErrorMessage.malformedAgeArmor =>
        SubscriptionUpdateResult.decryptFailed,
      LibXrayErrorMessage.agePlaintextTooLarge =>
        SubscriptionUpdateResult.contentTooLarge,
      LibXrayErrorMessage.agePlaintextUnsupported =>
        SubscriptionUpdateResult.invalidContent,
      _ => SubscriptionUpdateResult.invalidContent,
    };
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
