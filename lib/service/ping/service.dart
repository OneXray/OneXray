import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
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

  Future<void> pingOutboundConfigs(int subId) async {
    final eventBus = AppEventBus.instance;
    eventBus.updatePinging(true);
    final db = AppDatabase();
    final rows = await db.coreConfigDao.allOutboundRowsWithDataBySubId(subId);
    await _pingConfigs(db, rows);
    eventBus.updatePinging(false);
  }

  Future<int> _pingOutbound(CoreConfigData row, PingState pingState) async {
    if (EmptyTool.checkString(row.data)) {
      final outbound = OutboundState();
      outbound.readFromDbData(row);
      return outbound.ping(pingState);
    }
    return PingDelayConstants.unknown;
  }

  Future<void> pingRawConfigs(int subId) async {
    final eventBus = AppEventBus.instance;
    eventBus.updatePinging(true);
    final db = AppDatabase();
    final rows = await db.coreConfigDao.allRawRowsWithDataBySubId(subId);
    await _pingConfigs(db, rows);
    eventBus.updatePinging(false);
  }

  Future<int> _pingRawConfig(CoreConfigData row, PingState pingState) async {
    if (EmptyTool.checkString(row.data)) {
      final bytes = base64Decode(row.data!);
      final text = utf8.decode(bytes);
      return XrayRawPing.ping(text, pingState);
    }
    return PingDelayConstants.unknown;
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
        content = "error";
        break;
      default:
        content = "${delay}ms";
        break;
    }

    return content;
  }
}
