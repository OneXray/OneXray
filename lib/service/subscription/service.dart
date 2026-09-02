import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
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
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/ping/service.dart';
import 'package:onexray/service/share/xray_share_reader.dart';
import 'package:onexray/service/subscription/model.dart';
import 'package:onexray/service/subscription/validator.dart';

final class SubscriptionLoadResult {
  const SubscriptionLoadResult({
    required this.status,
    this.rows = const [],
    this.parseFailureCount,
  });

  final SubscriptionUpdateResult status;
  final List<CoreConfigCompanion> rows;
  final int? parseFailureCount;

  bool get hasUsableRows =>
      status == SubscriptionUpdateResult.success &&
      rows.isNotEmpty &&
      rows.every(
        (row) =>
            row.type.present && row.type.value == CoreConfigType.outbound.name,
      ) &&
      (parseFailureCount == null || parseFailureCount! >= 0);
}

typedef SubscriptionReferenceReader =
    FutureOr<SubscriptionNodeReferences> Function();

final class _SupersededSubscriptionUpdate implements Exception {
  const _SupersededSubscriptionUpdate();
}

class SubscriptionService {
  static final SubscriptionService _singleton = SubscriptionService._internal();

  factory SubscriptionService() => _singleton;

  SubscriptionService._internal()
    : _databaseOverride = null,
      _loadRowsOverride = null,
      _pingOverride = null;

  @visibleForTesting
  SubscriptionService.forTesting({
    required AppDatabase database,
    required Future<SubscriptionLoadResult> Function(SubscriptionInput)
    loadRows,
    required void Function(int) schedulePing,
    SubscriptionReferenceReader? readReferences,
  }) : _databaseOverride = database,
       _loadRowsOverride = loadRows,
       _pingOverride = schedulePing {
    referenceReader = readReferences ?? _currentReferences;
  }

  final AppDatabase? _databaseOverride;
  final Future<SubscriptionLoadResult> Function(SubscriptionInput)?
  _loadRowsOverride;
  final void Function(int)? _pingOverride;
  final _generations = <int, int>{};
  final _refreshes = <int, Future<SubscriptionRefreshResult>>{};
  var _nextGeneration = 0;

  /// P3 supplies all running node IDs plus persisted fixed/final-exit references.
  /// Favorites are checked in the same database transaction as replacement.
  SubscriptionReferenceReader referenceReader = _currentReferences;

  AppDatabase get _database => _databaseOverride ?? AppDatabase();

  static SubscriptionNodeReferences _currentReferences() {
    final state = AppEventBus.instance.state;
    // Transitional single-config runtime only; never consult old Preferences.
    return SubscriptionNodeReferences(
      runningIds: {state.runningId, state.pendingConfigId},
    );
  }

  void _schedulePing(int subId) {
    final schedule = _pingOverride;
    if (schedule != null) {
      schedule(subId);
    } else {
      PingService().schedulePingSubscription(subId);
    }
  }

  int _beginUpdate(int subId) {
    final generation = ++_nextGeneration;
    _generations[subId] = generation;
    return generation;
  }

  void _ensureCurrent(int subId, int generation) {
    if (_generations[subId] != generation) {
      throw const _SupersededSubscriptionUpdate();
    }
  }

  void _finishUpdate(int subId, int generation) {
    if (_generations[subId] == generation) {
      _generations.remove(subId);
    }
  }

  Future<bool> addSubscription(String url, String name, bool showLoading) =>
      DataMaintenance.run(() => _addSubscription(url, name, showLoading));

  Future<bool> _addSubscription(
    String url,
    String name,
    bool showLoading,
  ) async {
    final subscriptionName = name.isEmpty ? "anonymous" : name;
    final checked = await SubscriptionValidator.validate(subscriptionName, url);
    if (!checked.item1) {
      return false;
    }
    final result = await _insertSubscriptionWithLoading(
      SubscriptionInput(name: subscriptionName, url: url),
      showLoading,
    );
    return result.success;
  }

  Future<int> importSubscriptions(List<SubscriptionImportEntry> entries) =>
      DataMaintenance.run(() => _importSubscriptions(entries));

  Future<int> _importSubscriptions(
    List<SubscriptionImportEntry> entries,
  ) async {
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
        ygLogger(
          'import subscription failed (${error.runtimeType})\n$stackTrace',
        );
      }
    }
    for (final subId in importedSubIds) {
      _schedulePing(subId);
    }
    return imported;
  }

  Future<SubscriptionInsertResult> insertSubscription(
    SubscriptionInput input,
    bool showLoading,
  ) => DataMaintenance.run(
    () => _insertSubscriptionWithLoading(input, showLoading),
  );

  Future<SubscriptionInsertResult> _insertSubscriptionWithLoading(
    SubscriptionInput input,
    bool showLoading,
  ) async {
    final eventBus = showLoading ? AppEventBus.instance : null;
    eventBus?.updateDownloading(true);
    var result = const SubscriptionInsertResult(
      status: SubscriptionUpdateResult.writeFailed,
    );
    try {
      result = await _insertSubscription(input);
    } finally {
      eventBus?.updateDownloading(false);
    }

    if (result.success) {
      _schedulePing(result.subId);
    }

    return result;
  }

  Future<SubscriptionInsertResult> _insertSubscription(
    SubscriptionInput input,
  ) async {
    try {
      final loaded = await _loadRows(input);
      if (!loaded.hasUsableRows) {
        return SubscriptionInsertResult(
          status: loaded.status == SubscriptionUpdateResult.success
              ? SubscriptionUpdateResult.invalidContent
              : loaded.status,
          parseFailureCount: loaded.parseFailureCount,
        );
      }
      final rows = loaded.rows;
      final db = _database;
      return await db.transaction(() async {
        final row = SubscriptionCompanion.insert(
          name: input.name,
          url: input.url,
          ageSecretKey: Value(input.normalizedAgeSecretKey),
          agePublicKey: Value(input.normalizedAgePublicKey),
          timestamp: DateTime.now(),
          count: rows.length,
          expanded: true,
          parseFailureCount: loaded.parseFailureCount == null
              ? const Value.absent()
              : Value(loaded.parseFailureCount!),
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
          parseFailureCount: loaded.parseFailureCount,
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
    SubscriptionInput input, {
    bool showLoading = true,
  }) => DataMaintenance.run(() => _saveSubscription(id, input, showLoading));

  /// Editing a source changes future downloads, not its current node assets.
  Future<SubscriptionUpdateResult> saveSubscriptionInput(
    int id,
    SubscriptionInput input,
  ) => DataMaintenance.run(() async {
    final uri = Uri.tryParse(input.url);
    if (input.name.trim().isEmpty ||
        uri == null ||
        !NetClient.isHttpsDownloadUri(uri)) {
      return SubscriptionUpdateResult.invalidContent;
    }
    if (input.hasIncompleteAgeKeyPair) {
      return SubscriptionUpdateResult.invalidAgeSecretKey;
    }
    _refreshes.remove(id);
    final generation = _beginUpdate(id);
    try {
      return await _database.transaction(() async {
        final row = await _database.subscriptionDao.searchRow(id);
        _ensureCurrent(id, generation);
        if (row == null) return SubscriptionUpdateResult.notFound;
        if (await _database.subscriptionDao.urlExists(
          input.url,
          excludingId: id,
        )) {
          return SubscriptionUpdateResult.invalidContent;
        }
        final updated = await _database.subscriptionDao.updateRow(
          row.copyWith(
            name: input.name,
            url: input.url,
            ageSecretKey: Value(input.normalizedAgeSecretKey),
            agePublicKey: Value(input.normalizedAgePublicKey),
          ),
        );
        _ensureCurrent(id, generation);
        return updated
            ? SubscriptionUpdateResult.success
            : SubscriptionUpdateResult.writeFailed;
      });
    } catch (_) {
      return SubscriptionUpdateResult.writeFailed;
    } finally {
      _finishUpdate(id, generation);
    }
  });

  Future<void> setAutomaticUpdates(int id, bool enabled) =>
      DataMaintenance.run(() async {
        await _database.transaction(() async {
          final row = await _database.subscriptionDao.searchRow(id);
          if (row == null) throw StateError('Subscription no longer exists');
          await _database.subscriptionDao.updateRow(
            row.copyWith(autoUpdate: enabled),
          );
        });
      });

  Future<SubscriptionUpdateResult> _saveSubscription(
    int id,
    SubscriptionInput input,
    bool showLoading,
  ) async {
    if (input.hasIncompleteAgeKeyPair) {
      return SubscriptionUpdateResult.invalidAgeSecretKey;
    }
    _refreshes.remove(id);
    final generation = _beginUpdate(id);
    try {
      return await _updateSubscription(id, input, generation, showLoading);
    } on _SupersededSubscriptionUpdate {
      return SubscriptionUpdateResult.writeFailed;
    } catch (error, stackTrace) {
      ygLogger(
        'update subscription failed (${error.runtimeType})\n$stackTrace',
      );
      return SubscriptionUpdateResult.writeFailed;
    } finally {
      _finishUpdate(id, generation);
    }
  }

  /// The connection layer must confirm deletion and resolve affected running or
  /// persisted references before approving this destructive operation.
  Future<int> deleteSubscription(
    int id, {
    required Future<bool> Function(SubscriptionData) prepareDeletion,
  }) => DataMaintenance.run(() => _deleteSubscription(id, prepareDeletion));

  Future<int> _deleteSubscription(
    int id,
    Future<bool> Function(SubscriptionData) prepareDeletion,
  ) async {
    final db = _database;
    final source = await db.subscriptionDao.searchRow(id);
    if (source == null || !await prepareDeletion(source)) {
      return 0;
    }
    _refreshes.remove(id);
    final generation = _beginUpdate(id);
    try {
      return await db.transaction(() async {
        _ensureCurrent(id, generation);
        final deleted = await db.subscriptionDao.deleteRow(id);
        _ensureCurrent(id, generation);
        return deleted;
      });
    } on _SupersededSubscriptionUpdate {
      return 0;
    } finally {
      _finishUpdate(id, generation);
    }
  }

  Future<SubscriptionUpdateResult> _updateSubscription(
    int id,
    SubscriptionInput input,
    int generation,
    bool showLoading,
  ) async {
    final db = _database;
    final subscription = await db.subscriptionDao.searchRow(id);
    _ensureCurrent(id, generation);
    if (subscription == null) {
      return SubscriptionUpdateResult.notFound;
    }
    final ageSecretKey = input.normalizedAgeSecretKey;
    final agePublicKey = input.normalizedAgePublicKey;
    if (subscription.url == input.url &&
        subscription.ageSecretKey == ageSecretKey &&
        subscription.agePublicKey == agePublicKey) {
      return db.transaction(() async {
        final current = await db.subscriptionDao.searchRow(id);
        _ensureCurrent(id, generation);
        if (current == null) {
          return SubscriptionUpdateResult.notFound;
        }
        if (!_sameSource(current, subscription)) {
          throw const _SupersededSubscriptionUpdate();
        }
        final updated = await db.subscriptionDao.updateRow(
          current.copyWith(name: input.name),
        );
        _ensureCurrent(id, generation);
        return updated
            ? SubscriptionUpdateResult.success
            : SubscriptionUpdateResult.writeFailed;
      });
    }

    final eventBus = showLoading ? AppEventBus.instance : null;
    eventBus?.updateDownloading(true);
    try {
      final loaded = await _loadRows(input);
      _ensureCurrent(id, generation);
      if (!loaded.hasUsableRows) {
        return loaded.status == SubscriptionUpdateResult.success
            ? SubscriptionUpdateResult.invalidContent
            : loaded.status;
      }
      final result = await _replaceSubscription(
        subscription,
        loaded,
        generation,
        editedInput: input,
      );
      if (result.success) {
        _schedulePing(subscription.id);
      }
      return result.status;
    } finally {
      eventBus?.updateDownloading(false);
    }
  }

  Future<int> refreshSubscription(
    SubscriptionData subscription,
    bool showLoading,
  ) async {
    final result = await refreshSubscriptionResult(subscription, showLoading);
    return result.success ? result.count : 0;
  }

  /// Prefer this result for reporting: an obsolete request is not a zero-node
  /// success, and unavailable parse statistics remain null.
  Future<SubscriptionRefreshResult> refreshSubscriptionResult(
    SubscriptionData subscription,
    bool showLoading,
  ) => DataMaintenance.run(
    () => _refreshSubscriptionResult(subscription, showLoading),
  );

  Future<SubscriptionRefreshResult> _refreshSubscriptionResult(
    SubscriptionData subscription,
    bool showLoading,
  ) {
    final pending = _refreshes[subscription.id];
    if (pending != null) {
      return pending;
    }
    if (_generations.containsKey(subscription.id)) {
      // A background refresh must not cancel an in-flight user edit/deletion.
      return Future.value(
        const SubscriptionRefreshResult(
          status: SubscriptionUpdateResult.writeFailed,
          superseded: true,
        ),
      );
    }
    final generation = _beginUpdate(subscription.id);
    late final Future<SubscriptionRefreshResult> task;
    task = _refreshSubscription(subscription.id, showLoading, generation)
        .whenComplete(() {
          if (identical(_refreshes[subscription.id], task)) {
            _refreshes.remove(subscription.id);
          }
          _finishUpdate(subscription.id, generation);
        });
    _refreshes[subscription.id] = task;
    return task;
  }

  Future<SubscriptionRefreshResult> _refreshSubscription(
    int id,
    bool showLoading,
    int generation,
  ) async {
    final eventBus = showLoading ? AppEventBus.instance : null;
    eventBus?.updateDownloading(true);
    try {
      final subscription = await _database.subscriptionDao.searchRow(id);
      _ensureCurrent(id, generation);
      if (subscription == null) {
        return const SubscriptionRefreshResult(
          status: SubscriptionUpdateResult.notFound,
        );
      }
      final loaded = await _loadRows(
        SubscriptionInput(
          name: subscription.name,
          url: subscription.url,
          ageSecretKey: subscription.ageSecretKey,
          agePublicKey: subscription.agePublicKey,
        ),
      );
      _ensureCurrent(id, generation);
      if (!loaded.hasUsableRows) {
        return SubscriptionRefreshResult(
          status: loaded.status == SubscriptionUpdateResult.success
              ? SubscriptionUpdateResult.invalidContent
              : loaded.status,
          parseFailureCount: loaded.parseFailureCount,
        );
      }
      final result = await _replaceSubscription(
        subscription,
        loaded,
        generation,
      );
      if (result.success) {
        _schedulePing(id);
      }
      return result;
    } on _SupersededSubscriptionUpdate {
      return const SubscriptionRefreshResult(
        status: SubscriptionUpdateResult.writeFailed,
        superseded: true,
      );
    } catch (error, stackTrace) {
      ygLogger(
        'refresh subscription failed (${error.runtimeType})\n$stackTrace',
      );
      return const SubscriptionRefreshResult(
        status: SubscriptionUpdateResult.writeFailed,
      );
    } finally {
      eventBus?.updateDownloading(false);
    }
  }

  Future<SubscriptionRefreshResult> _replaceSubscription(
    SubscriptionData expected,
    SubscriptionLoadResult loaded,
    int generation, {
    SubscriptionInput? editedInput,
  }) {
    final db = _database;
    return db.transaction(() async {
      _ensureCurrent(expected.id, generation);
      final current = await db.subscriptionDao.searchRow(expected.id);
      if (current == null) {
        return const SubscriptionRefreshResult(
          status: SubscriptionUpdateResult.notFound,
        );
      }
      if (!_sameSource(current, expected)) {
        throw const _SupersededSubscriptionUpdate();
      }
      final references = await referenceReader();
      _ensureCurrent(expected.id, generation);
      await db.subscriptionDao.deleteConfigs(
        current.id,
        protectedIds: references.protectedIds,
      );
      final count = await ConfigWriter.writeRowsBatchInTransaction(
        db,
        loaded.rows,
        current.id,
      );
      if (count != loaded.rows.length) {
        throw StateError('replace subscription configs failed');
      }
      final updated = current.copyWith(
        name: editedInput?.name ?? current.name,
        url: editedInput?.url ?? current.url,
        ageSecretKey: editedInput == null
            ? const Value.absent()
            : Value(editedInput.normalizedAgeSecretKey),
        agePublicKey: editedInput == null
            ? const Value.absent()
            : Value(editedInput.normalizedAgePublicKey),
        timestamp: DateTime.now(),
        count: count,
        parseFailureCount:
            loaded.parseFailureCount ?? current.parseFailureCount,
      );
      _ensureCurrent(expected.id, generation);
      if (!await db.subscriptionDao.updateRow(updated)) {
        throw StateError('update subscription failed');
      }
      _ensureCurrent(expected.id, generation);
      return SubscriptionRefreshResult(
        status: SubscriptionUpdateResult.success,
        count: count,
        parseFailureCount: loaded.parseFailureCount,
      );
    });
  }

  static bool _sameSource(
    SubscriptionData current,
    SubscriptionData expected,
  ) =>
      current.url == expected.url &&
      current.ageSecretKey == expected.ageSecretKey &&
      current.agePublicKey == expected.agePublicKey;

  Future<SubscriptionLoadResult> _loadRows(SubscriptionInput input) async {
    if (input.hasIncompleteAgeKeyPair) {
      return const SubscriptionLoadResult(
        status: SubscriptionUpdateResult.invalidAgeSecretKey,
      );
    }
    final loadRows = _loadRowsOverride;
    if (loadRows != null) {
      return loadRows(input);
    }
    final ageContext = input.normalizedAgeContext;

    final text = await NetClient().getText(
      input.url,
      httpsOnly: true,
      requestHeaders: DownloadRequestHeaders(
        agePublicKey: ageContext?.publicKey,
      ),
    );
    if (text == null) {
      return const SubscriptionLoadResult(
        status: SubscriptionUpdateResult.downloadFailed,
      );
    }

    try {
      final report = await XrayShareReader().parseShareTextReport(
        text,
        ageSecretKey: ageContext?.secretKey,
      );
      return SubscriptionLoadResult(
        status: report.rows.isEmpty
            ? SubscriptionUpdateResult.invalidContent
            : SubscriptionUpdateResult.success,
        rows: report.rows,
        parseFailureCount: report.failureCount,
      );
    } on LibXrayInvokeException catch (error) {
      return SubscriptionLoadResult(status: _ageErrorStatus(error.message));
    } catch (error, stackTrace) {
      ygLogger('parse subscription failed (${error.runtimeType})\n$stackTrace');
      return const SubscriptionLoadResult(
        status: SubscriptionUpdateResult.invalidContent,
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

  Future<void> refreshAllSubscription({bool updateDownloading = true}) =>
      DataMaintenance.run(() => _refreshAllSubscription(updateDownloading));

  Future<void> _refreshAllSubscription(bool updateDownloading) async {
    final eventBus = updateDownloading ? AppEventBus.instance : null;
    eventBus?.updateDownloading(true);
    try {
      final db = _database;
      final subscriptions = await db.subscriptionDao.allRows;
      for (final subscription in subscriptions) {
        await _refreshSubscriptionResult(subscription, false);
      }
    } finally {
      eventBus?.updateDownloading(false);
    }
  }

  Future<void> refreshOutdatedSubscription({
    AutoUpdateState? autoUpdateState,
    bool updateDownloading = true,
  }) => DataMaintenance.run(
    () => _refreshOutdatedSubscription(autoUpdateState, updateDownloading),
  );

  Future<void> _refreshOutdatedSubscription(
    AutoUpdateState? autoUpdateState,
    bool updateDownloading,
  ) async {
    final eventBus = updateDownloading ? AppEventBus.instance : null;
    eventBus?.updateDownloading(true);
    try {
      final updateState = autoUpdateState ?? AutoUpdateState();
      if (autoUpdateState == null) {
        await updateState.readFromPreferences();
      }
      if (!updateState.subscriptionEnabled) {
        return;
      }
      final interval = updateState.subscriptionInterval.value;
      final subs = await _database.subscriptionDao.allRows;
      final now = DateTime.now();
      for (final sub in subs) {
        if (sub.autoUpdate &&
            now.difference(sub.timestamp).inHours >= interval) {
          await _refreshSubscriptionResult(sub, false);
        }
      }
    } finally {
      eventBus?.updateDownloading(false);
    }
  }
}
