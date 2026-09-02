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
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/ping/batch.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/xray/outbound/map.dart';
import 'package:onexray/service/xray/outbound/state_db.dart';

class PingService {
  static final PingService _singleton = PingService._internal();

  factory PingService() => _singleton;

  PingService._internal();

  Future<void> _scheduledPingQueue = Future.value();
  var _pingingTaskCount = 0;

  Future<void> pingOutboundConfigs(int subId) async {
    final db = AppDatabase();
    await _runPinging(() async {
      final rows = await db.coreConfigDao.allOutboundRowsWithDataBySubId(subId);
      await _pingConfigs(db, rows);
    });
  }

  Future<void> pingHomeNodeConfigs(int subId) async {
    final db = AppDatabase();
    await _runPinging(() async {
      final rows = await db.coreConfigDao.allHomeNodeRowsWithDataBySubId(subId);
      await _pingConfigs(db, rows);
    });
  }

  void schedulePingConfigIds(List<int> ids) {
    final targetIds = ids
        .where((id) => id > DBConstants.defaultId)
        .toSet()
        .toList();
    if (targetIds.isEmpty) {
      return;
    }
    _enqueueAutoPing(() async {
      final db = AppDatabase();
      final rows = <CoreConfigData>[];
      for (final id in targetIds) {
        final row = await db.coreConfigDao.searchRow(id);
        if (row != null && _isPingableConfig(row)) {
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
    _enqueueAutoPing(() async {
      final db = AppDatabase();
      final rows = <CoreConfigData>[];
      for (final subId in targetSubIds) {
        rows.addAll(
          await db.coreConfigDao.allOutboundRowsWithDataBySubId(subId),
        );
      }
      if (rows.isEmpty) {
        return;
      }
      await _runPinging(() => _pingConfigs(db, rows));
    });
  }

  void _enqueueAutoPing(Future<void> Function() task) {
    _scheduledPingQueue = _scheduledPingQueue.then((_) async {
      try {
        final pingState = PingState();
        await pingState.readFromPreferences();
        if (!pingState.autoPingNewConfigs) {
          return;
        }
        await DataMaintenance.run(task);
      } catch (e, stackTrace) {
        ygLogger("Auto ping failed: $e\n$stackTrace");
      }
    });
  }

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

  Future<void> pingRawConfig(int id) async {
    final db = AppDatabase();
    await _runPinging(() async {
      final row = await db.coreConfigDao.searchRow(id);
      if (row == null ||
          CoreConfigType.fromString(row.type) != CoreConfigType.raw) {
        throw StateError('Raw configuration not found');
      }
      await _pingConfigs(db, [row]);
    });
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
      final results = await PingBatchRunner.run(sources, pingState);
      await db.transaction(() async {
        for (var index = 0; index < results.length; index++) {
          await _updateRow(db, batchRows[index], results[index].delay);
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

  Future<void> _updateRow(AppDatabase db, CoreConfigData row, int delay) async {
    if (delay == PingDelayConstants.unknown || row.data == null) return;
    // A slow result must not overwrite an edit, favorite, or restored asset.
    await (db.update(db.coreConfig)..where(
          (table) =>
              table.id.equals(row.id) &
              table.type.equals(row.type) &
              table.data.equals(row.data!),
        ))
        .write(
          CoreConfigCompanion(
            delay: Value(delay),
            lastMeasuredAt: Value(DateTime.now()),
          ),
        );
  }

  String parsePingResponse(int delay) {
    var content = "";
    switch (delay) {
      case PingDelayConstants.timeout:
        content = appLocalizationsNoContext().pingTimeout;
        break;
      case PingDelayConstants.error:
        content = appLocalizationsNoContext().pingError;
        break;
      default:
        content = "${delay}ms";
        break;
    }

    return content;
  }
}
