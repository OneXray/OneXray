import 'dart:async';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/dao/config_query.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/db/table/core_config.dart';
import 'package:onexray/core/db/table/subscription.dart';

part 'core_config.g.dart';

@DriftAccessor(tables: [CoreConfig, Subscription])
class CoreConfigDao extends DatabaseAccessor<AppDatabase>
    with _$CoreConfigDaoMixin {
  CoreConfigDao(super.db);

  CoreConfigData _convertRowToCoreConfigData(TypedResult row) {
    final id = row.read(coreConfig.id);
    final name = row.read(coreConfig.name);
    final type = row.read(coreConfig.type);
    final tags = row.read(coreConfig.tags);
    final delay = row.read(coreConfig.delay);
    final subId = row.read(coreConfig.subId);
    final data = CoreConfigData(
      id: id ?? DBConstants.defaultId,
      name: name ?? "",
      type: type ?? CoreConfigType.outbound.name,
      tags: tags ?? "",
      delay: delay ?? PingDelayConstants.unknown,
      subId: subId ?? DBConstants.defaultId,
    );
    return data;
  }

  Future<Map<int, ConfigGroup>> _buildSubscriptionGroups() async {
    final groups = <int, ConfigGroup>{};
    final subscriptions = await _getAllSubscriptions();
    final localSub = await _readLocalSubscription();
    subscriptions.add(localSub);
    for (final sub in subscriptions) {
      final subItem = SubscriptionItem(sub, ConfigQueryRowType.subscription);
      final group = ConfigGroup(sub.id, subItem, []);
      groups[sub.id] = group;
    }
    return groups;
  }

  List<ConfigQueryRow> _flattenExpandedGroups(Map<int, ConfigGroup> groups) {
    final sortedGroups = groups.values
        .sorted((a, b) => a.subId.compareTo(b.subId))
        .toList();
    final results = <ConfigQueryRow>[];
    for (final group in sortedGroups) {
      results.add(group.subscription);
      if (group.subscription.subscription.expanded) {
        results.addAll(group.configs);
      }
    }

    return results;
  }

  void _syncGroupCounts(Map<int, ConfigGroup> groups) {
    for (final group in groups.values) {
      group.subscription.count = group.count;
    }
    final localGroup = groups[DBConstants.defaultId];
    if (localGroup == null) {
      return;
    }
    var sub = localGroup.subscription.subscription;
    sub = sub.copyWith(count: localGroup.count);
    localGroup.subscription.subscription = sub;
  }

  Future<List<ConfigQueryRow>> _convertGroupedQueryRows(
    List<TypedResult> rows, {
    required int? Function(CoreConfigData data, CoreConfigType? type)
    resolveSubId,
    CoreConfigData Function(CoreConfigData data, CoreConfigType? type)?
    normalizeData,
  }) async {
    final groups = await _buildSubscriptionGroups();

    for (final row in rows) {
      var data = _convertRowToCoreConfigData(row);
      final type = CoreConfigType.fromString(data.type);
      final subId = resolveSubId(data, type);
      if (subId == null || !groups.containsKey(subId)) {
        continue;
      }
      data = normalizeData?.call(data, type) ?? data;
      final group = groups[subId]!;
      final configItem = ConfigItem(data, ConfigQueryRowType.config);
      group.configs.add(configItem);
      group.count += 1;
    }

    _syncGroupCounts(groups);
    return _flattenExpandedGroups(groups);
  }

  Future<List<ConfigQueryRow>> _convertOutboundQueryRows(
    List<TypedResult> rows,
  ) {
    return _convertGroupedQueryRows(
      rows,
      resolveSubId: (data, _) => data.subId,
    );
  }

  Future<List<ConfigQueryRow>> _convertHomeNodeQueryRows(
    List<TypedResult> rows,
  ) {
    return _convertGroupedQueryRows(
      rows,
      resolveSubId: (data, type) => switch (type) {
        CoreConfigType.raw => DBConstants.defaultId,
        CoreConfigType.full => DBConstants.defaultId,
        CoreConfigType.outbound => data.subId,
        _ => null,
      },
      normalizeData: (data, type) {
        if (type == CoreConfigType.raw || type == CoreConfigType.full) {
          return data.copyWith(subId: DBConstants.defaultId);
        }
        return data;
      },
    );
  }

  List<ConfigQueryRow> _convertSettingQueryRows(List<TypedResult> rows) {
    if (rows.isEmpty) {
      return [];
    }

    final localSub = SubscriptionData(
      id: DBConstants.defaultId,
      name: "Local",
      url: "",
      timestamp: DateTime.now(),
      count: rows.length,
      expanded: true,
    );
    final localItem = SubscriptionItem(
      localSub,
      ConfigQueryRowType.subscription,
    )..count = rows.length;

    return [
      localItem,
      ...rows.map((row) {
        final data = _convertRowToCoreConfigData(
          row,
        ).copyWith(subId: DBConstants.defaultId);
        return ConfigItem(data, ConfigQueryRowType.config);
      }),
    ];
  }

  JoinedSelectStatement<$CoreConfigTable, CoreConfigData>
  get _allConfigRowsQuery {
    final query = selectOnly(coreConfig)
      ..orderBy([OrderingTerm.asc(coreConfig.delay)])
      ..addColumns([
        coreConfig.id,
        coreConfig.name,
        coreConfig.type,
        coreConfig.tags,
        coreConfig.delay,
        coreConfig.subId,
      ]);
    return query;
  }

  Stream<List<ConfigQueryRow>> allOutboundRowsStream() async* {
    final query = _allConfigRowsQuery
      ..where(coreConfig.type.equals(CoreConfigType.outbound.name));
    final queryStream = query.watch();
    await for (final rows in queryStream) {
      final results = await _convertOutboundQueryRows(rows);
      yield results;
    }
  }

  Future<List<ConfigQueryRow>> get allOutboundRows async {
    final query = _allConfigRowsQuery
      ..where(coreConfig.type.equals(CoreConfigType.outbound.name));
    final rows = await query.get();
    return _convertOutboundQueryRows(rows);
  }

  Stream<List<ConfigQueryRow>> allHomeNodeRowsStream() async* {
    final query = _allConfigRowsQuery
      ..where(
        coreConfig.type.equals(CoreConfigType.outbound.name) |
            coreConfig.type.equals(CoreConfigType.raw.name) |
            coreConfig.type.equals(CoreConfigType.full.name),
      );
    final queryStream = query.watch();
    await for (final rows in queryStream) {
      final results = await _convertHomeNodeQueryRows(rows);
      yield results;
    }
  }

  Future<List<ConfigQueryRow>> get allHomeNodeRows async {
    final query = _allConfigRowsQuery
      ..where(
        coreConfig.type.equals(CoreConfigType.outbound.name) |
            coreConfig.type.equals(CoreConfigType.raw.name) |
            coreConfig.type.equals(CoreConfigType.full.name),
      );
    final rows = await query.get();
    final results = await _convertHomeNodeQueryRows(rows);
    return results;
  }

  Stream<List<ConfigQueryRow>> allSettingRowsStream() async* {
    final query = _allConfigRowsQuery
      ..where(coreConfig.type.equals(CoreConfigType.profile.name));
    final queryStream = query.watch();
    await for (final rows in queryStream) {
      final results = _convertSettingQueryRows(rows);
      yield results;
    }
  }

  Future<List<ConfigQueryRow>> get allSettingRows async {
    final query = _allConfigRowsQuery
      ..where(coreConfig.type.equals(CoreConfigType.profile.name));
    final rows = await query.get();
    final results = _convertSettingQueryRows(rows);
    return results;
  }

  Future<List<CoreConfigData>> allOutboundRowsWithDataBySubId(
    int subId,
  ) async =>
      (select(coreConfig)
            ..where((tbl) => tbl.type.equals(CoreConfigType.outbound.name))
            ..where((tbl) => tbl.subId.equals(subId))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.delay)]))
          .get();

  Stream<List<CoreConfigData>> allOutboundRowsWithDataBySubIdStream(int subId) {
    return (select(coreConfig)
          ..where((tbl) => tbl.type.equals(CoreConfigType.outbound.name))
          ..where((tbl) => tbl.subId.equals(subId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.delay)]))
        .watch();
  }

  Future<List<CoreConfigData>> allHomeNodeRowsWithDataBySubId(int subId) async {
    if (subId == DBConstants.defaultId) {
      return (select(coreConfig)
            ..where(
              (tbl) =>
                  (tbl.type.equals(CoreConfigType.outbound.name) &
                      tbl.subId.equals(DBConstants.defaultId)) |
                  tbl.type.equals(CoreConfigType.raw.name) |
                  tbl.type.equals(CoreConfigType.full.name),
            )
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.delay)]))
          .get();
    }
    return allOutboundRowsWithDataBySubId(subId);
  }

  Future<List<CoreConfigData>> get allLocalRowsWithData async => (select(
    coreConfig,
  )..where((tbl) => tbl.subId.equals(DBConstants.defaultId))).get();

  Future<SubscriptionData> _readLocalSubscription() async {
    final expanded = await PreferencesKey().readLocalSubscriptionExpanded();
    final subData = SubscriptionData(
      id: DBConstants.defaultId,
      name: "Local",
      url: "",
      timestamp: DateTime.now(),
      count: 0,
      expanded: expanded,
    );
    return subData;
  }

  Future<CoreConfigData?> searchRow(int id) async {
    return (select(
      coreConfig,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<CoreConfigData?> randomConfig() async {
    final res =
        await (select(coreConfig)..where(
              (tbl) => tbl.type.equals(CoreConfigType.profile.name).not(),
            ))
            .get();
    if (res.isNotEmpty) {
      return res.first;
    }
    return null;
  }

  Future<bool> updateRow(CoreConfigData entry) async {
    return update(coreConfig).replace(entry);
  }

  Future<int> insertRow(CoreConfigCompanion entry) async {
    return into(coreConfig).insert(entry);
  }

  Future<int> insertRows(List<CoreConfigCompanion> entries) async {
    if (entries.isEmpty) {
      return 0;
    }
    await coreConfig.insertAll(entries);
    return entries.length;
  }

  Future<int> copyRow(int coreConfigId) async {
    final entry = await searchRow(coreConfigId);
    if (entry == null) {
      return 0;
    }
    final row = CoreConfigCompanion.insert(
      type: entry.type,
      name: entry.name,
      tags: entry.tags,
      data: Value<String?>(entry.data),
      delay: entry.delay,
      subId: DBConstants.defaultId,
    );
    return insertRow(row);
  }

  Future<int> deleteRow(CoreConfigData entry) async {
    final res = await (delete(
      coreConfig,
    )..where((tbl) => tbl.id.equals(entry.id))).go();
    if (entry.subId != DBConstants.defaultId) {
      final sub = await _searchSubscription(entry.subId);
      if (sub != null) {
        final newSub = sub.copyWith(count: sub.count - res);
        await _updateSubscription(newSub);
      }
    }
    notifyUpdates({
      TableUpdate.onTable(coreConfig, kind: UpdateKind.delete),
      TableUpdate.onTable(subscription, kind: UpdateKind.update),
    });
    return res;
  }

  Future<int> deleteUnreachableOutboundRows(int subId) async {
    final res =
        await (delete(coreConfig)
              ..where((tbl) => tbl.subId.equals(subId))
              ..where((tbl) => tbl.type.equals(CoreConfigType.outbound.name))
              ..where(
                (tbl) =>
                    tbl.delay.isBiggerThanValue(PingDelayConstants.unknown),
              ))
            .go();
    if (subId != DBConstants.defaultId) {
      final sub = await _searchSubscription(subId);
      if (sub != null) {
        final newSub = sub.copyWith(count: sub.count - res);
        await _updateSubscription(newSub);
      }
    }
    notifyUpdates({
      TableUpdate.onTable(coreConfig, kind: UpdateKind.delete),
      TableUpdate.onTable(subscription, kind: UpdateKind.update),
    });
    return res;
  }

  Future<int> deleteUnreachableHomeNodeRows(int subId) async {
    if (subId != DBConstants.defaultId) {
      return deleteUnreachableOutboundRows(subId);
    }
    final res =
        await (delete(coreConfig)
              ..where(
                (tbl) =>
                    (tbl.type.equals(CoreConfigType.outbound.name) &
                        tbl.subId.equals(DBConstants.defaultId)) |
                    tbl.type.equals(CoreConfigType.raw.name) |
                    tbl.type.equals(CoreConfigType.full.name),
              )
              ..where(
                (tbl) =>
                    tbl.delay.isBiggerThanValue(PingDelayConstants.unknown),
              ))
            .go();
    notifyUpdates({TableUpdate.onTable(coreConfig, kind: UpdateKind.delete)});
    return res;
  }

  Future<List<SubscriptionData>> _getAllSubscriptions() async {
    return select(subscription).get();
  }

  Future<SubscriptionData?> _searchSubscription(int id) async {
    return (select(
      subscription,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<bool> _updateSubscription(SubscriptionData entry) async {
    return update(subscription).replace(entry);
  }

  Future<int> clear() async {
    final res = await delete(coreConfig).go();
    return res;
  }
}
