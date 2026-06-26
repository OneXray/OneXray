import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_ping.dart';
import 'package:onexray/service/xray/outbound/state_reader.dart';
import 'package:onexray/service/xray/raw/ping.dart';

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

  Future<int> _pingOutbound(CoreConfigData row, PingState pingState) async {
    if (EmptyTool.checkString(row.data)) {
      final outbound = OutboundState();
      outbound.readFromDbData(row);
      return outbound.ping(pingState);
    }
    return PingDelayConstants.unknown;
  }

  Future<void> pingRawConfigs() async {
    final db = AppDatabase();
    await _runPinging(() async {
      final rows = await db.coreConfigDao.allRawRowsWithData;
      await _pingConfigs(db, rows);
    });
  }

  Future<int> _pingRawConfig(CoreConfigData row, PingState pingState) async {
    if (EmptyTool.checkString(row.data)) {
      final bytes = base64Decode(row.data!);
      final text = utf8.decode(bytes);
      return XrayRawPing.ping(text, pingState);
    }
    return PingDelayConstants.unknown;
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
    if (subId <= DBConstants.defaultId) {
      return;
    }
    _enqueueAutoPing(() async {
      final db = AppDatabase();
      final rows = await db.coreConfigDao.allOutboundRowsWithDataBySubId(subId);
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
        await task();
      } catch (e, stackTrace) {
        ygLogger("Auto ping failed: $e\n$stackTrace");
      }
    });
  }

  Future<void> _runPinging(Future<void> Function() task) async {
    _startPinging();
    try {
      await task();
    } finally {
      _stopPinging();
    }
  }

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
    final type = CoreConfigType.fromString(row.type);
    return type == CoreConfigType.outbound || type == CoreConfigType.raw;
  }

  Future<void> _pingConfigs(AppDatabase db, List<CoreConfigData> rows) async {
    final pingState = PingState();
    await pingState.readFromPreferences();
    var concurrency = pingState.concurrency.toInt();
    if (AppPlatform.isLinux || AppPlatform.isWindows) {
      concurrency = 1;
    }
    final slices = rows.slices(concurrency);
    for (final slice in slices) {
      final tempRows = <CoreConfigData>[];
      final group = FutureGroup<int>();
      for (final row in slice) {
        tempRows.add(row);
        _addTaskToGroup(group, row, pingState);
      }
      group.close();
      final res = await group.future;
      for (int i = 0; i < tempRows.length; i++) {
        await _updateRow(db, tempRows[i], res[i]);
      }
    }
  }

  void _addTaskToGroup(
    FutureGroup group,
    CoreConfigData row,
    PingState pingState,
  ) {
    final type = CoreConfigType.fromString(row.type);
    if (type != null) {
      switch (type) {
        case CoreConfigType.outbound:
          group.add(_pingOutbound(row, pingState));
          break;
        case CoreConfigType.raw:
          group.add(_pingRawConfig(row, pingState));
          break;
        default:
          break;
      }
    }
  }

  Future<void> _updateRow(AppDatabase db, CoreConfigData row, int delay) async {
    var newRow = row;
    if (delay != PingDelayConstants.unknown) {
      newRow = newRow.copyWith(delay: delay);
    }
    await db.coreConfigDao.updateRow(newRow);
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
