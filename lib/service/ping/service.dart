import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/ping/batch.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';

class PingService {
  static final PingService _singleton = PingService._internal();

  factory PingService() => _singleton;

  PingService._internal() : _databaseOverride = null, _batchOverride = null;

  PingService.forTesting({
    required AppDatabase database,
    required Future<List<PingBatchResult>> Function(
      List<PingBatchSource>,
      PingState,
    )
    runBatch,
  }) : _databaseOverride = database,
       _batchOverride = runBatch;

  final AppDatabase? _databaseOverride;
  final Future<List<PingBatchResult>> Function(
    List<PingBatchSource>,
    PingState,
  )?
  _batchOverride;

  AppDatabase get _database => _databaseOverride ?? AppDatabase();

  Future<void> _scheduledPingQueue = Future.value();
  var _pingingTaskCount = 0;

  void schedulePingConfigIds(List<int> ids) {
    unawaited(pingConfigIds(ids));
  }

  /// Shares the existing serialized queue with automatic imports. Each batch
  /// commits independently, so DB watchers may finish selecting before this does.
  Future<void> pingConfigIds(List<int> ids, {bool force = false}) {
    final targetIds = ids
        .where((id) => id > DBConstants.defaultId)
        .toSet()
        .toList();
    if (targetIds.isEmpty) {
      return Future.value();
    }
    return _enqueuePing(() async {
      final db = _database;
      final rows = <CoreConfigData>[];
      for (final id in targetIds) {
        final row = await db.coreConfigDao.searchRow(id);
        if (row != null &&
            _isPingableConfig(row) &&
            (force || isUnmeasured(row))) {
          rows.add(row);
        }
      }
      if (rows.isEmpty) {
        return;
      }
      await _runPinging(() => _pingConfigs(db, rows));
    });
  }

  void schedulePingSubscription(int subId) {
    schedulePingSubscriptions([subId]);
  }

  void schedulePingSubscriptions(Iterable<int> subIds) {
    final targetSubIds = subIds
        .where((id) => id > DBConstants.defaultId)
        .toSet()
        .toList(growable: false);
    if (targetSubIds.isEmpty) {
      return;
    }
    unawaited(
      _enqueuePing(() async {
        final db = _database;
        final rows = <CoreConfigData>[];
        for (final subId in targetSubIds) {
          rows.addAll(
            (await db.coreConfigDao.allOutboundRowsWithDataBySubId(subId))
                .where(isUnmeasured),
          );
        }
        if (rows.isEmpty) {
          return;
        }
        await _runPinging(() => _pingConfigs(db, rows));
      }),
    );
  }

  Future<void> _enqueuePing(Future<void> Function() task) {
    final previous = _scheduledPingQueue;
    // Register while queued, not after waiting: restore must not finish and
    // then receive a stale job against restored rows with the same IDs.
    final next = DataMaintenance.run(() async {
      await previous;
      await task();
    });
    _scheduledPingQueue = next.catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      ygLogger('Queued ping failed (${error.runtimeType})\n$stackTrace');
    });
    return next;
  }

  static bool isUnmeasured(CoreConfigData row) =>
      row.delay == PingDelayConstants.unknown;

  Future<void> _runPinging(Future<void> Function() task) =>
      DataMaintenance.run(() async {
        _startPinging();
        try {
          await task();
        } finally {
          _stopPinging();
        }
      });

  void _startPinging() {
    _pingingTaskCount += 1;
    if (_pingingTaskCount == 1) {
      AppEventBus.instance.updatePinging(true);
    }
  }

  void _stopPinging() {
    if (_pingingTaskCount > 0) {
      _pingingTaskCount -= 1;
    }
    if (_pingingTaskCount == 0) {
      AppEventBus.instance.updatePinging(false);
    }
  }

  bool _isPingableConfig(CoreConfigData row) {
    return CoreConfigType.fromString(row.type) == CoreConfigType.outbound;
  }

  Future<void> _pingConfigs(AppDatabase db, List<CoreConfigData> rows) async {
    final pingState = PingState();
    await pingState.readFromPreferences();

    for (final rowSlice in rows.slices(PingBatchRunner.maxBatchSize)) {
      final batchRows = <CoreConfigData>[];
      final sources = <PingBatchSource>[];
      for (final row in rowSlice) {
        final source = _makePingSource(row);
        if (source != null) {
          batchRows.add(row);
          sources.add(source);
        }
      }
      final results = await (_batchOverride ?? PingBatchRunner.run)(
        sources,
        pingState,
      );
      await db.transaction(() async {
        for (var index = 0; index < results.length; index++) {
          final result = results[index];
          final delay = result.success
              ? result.delay
              : result.delay == PingDelayConstants.timeout
              ? PingDelayConstants.timeout
              : PingDelayConstants.error;
          await _updateRow(db, batchRows[index], delay, result.countryCode);
        }
      });
    }
  }

  PingBatchSource? _makePingSource(CoreConfigData row) {
    if (!EmptyTool.checkString(row.data)) {
      return null;
    }
    try {
      final type = CoreConfigType.fromString(row.type);
      switch (type) {
        case CoreConfigType.outbound:
          final outbound = readOutboundFromDbData(row);
          requireCanonicalOutbound(outbound);
          return PingBatchSource(encodeSingleOutbound(outbound));
        case CoreConfigType.raw:
          final bytes = base64Decode(row.data!);
          return PingBatchSource(utf8.decode(bytes));
        default:
          return null;
      }
    } catch (error) {
      ygLogger("Prepare ping source failed: ${row.id}, ${error.runtimeType}");
      return null;
    }
  }

  Future<void> _updateRow(
    AppDatabase db,
    CoreConfigData row,
    int delay,
    String? countryCode,
  ) async {
    if (delay == PingDelayConstants.unknown || row.data == null) return;
    final country =
        countryCode != null && RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)
        ? countryCode
        : null;
    // A slow result must not overwrite an edit, favorite, or restored asset.
    await (db.update(db.coreConfig)..where(
          (table) =>
              table.id.equals(row.id) &
              table.subId.equals(row.subId) &
              table.type.equals(row.type) &
              table.data.equals(row.data!),
        ))
        .write(
          CoreConfigCompanion(delay: Value(delay), countryCode: Value(country)),
        );
  }
}
