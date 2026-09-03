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
      countryCode: row.read(coreConfig.countryCode),
      favorite: row.read(coreConfig.favorite) ?? false,
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
      if (group.subId == DBConstants.defaultId && group.count == 0) {
        continue;
      }
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
        coreConfig.countryCode,
        coreConfig.favorite,
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

  Stream<List<ConfigQueryRow>> allHomeNodeRowsStream() =>
      allOutboundRowsStream();

  Future<List<ConfigQueryRow>> get allHomeNodeRows => allOutboundRows;

  // Compatibility for the retiring Profile page; legacy rows stay in storage.
  Stream<List<ConfigQueryRow>> allSettingRowsStream() => Stream.value([]);

  Future<List<ConfigQueryRow>> get allSettingRows async => [];

  Future<List<CoreConfigData>> get allRawRowsWithData =>
      (select(coreConfig)
            ..where((table) => table.type.equals(CoreConfigType.raw.name))
            ..orderBy([(table) => OrderingTerm.asc(table.id)]))
          .get();

  Stream<List<CoreConfigData>> get allRawRowsWithDataStream =>
      (select(coreConfig)
            ..where((table) => table.type.equals(CoreConfigType.raw.name))
            ..orderBy([(table) => OrderingTerm.asc(table.id)]))
          .watch();

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

  Future<List<CoreConfigData>> allHomeNodeRowsWithDataBySubId(int subId) =>
      allOutboundRowsWithDataBySubId(subId);

  Future<List<CoreConfigData>> get allLocalRowsWithData async =>
      (select(coreConfig)..where(
            (tbl) =>
                (tbl.type.equals(CoreConfigType.outbound.name) &
                    tbl.subId.equals(DBConstants.defaultId)) |
                tbl.type.equals(CoreConfigType.raw.name),
          ))
          .get();

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
    return (select(coreConfig)
          ..where((tbl) => tbl.type.equals(CoreConfigType.outbound.name))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<bool> updateRow(CoreConfigData entry) async {
    if (entry.type != CoreConfigType.outbound.name &&
        entry.type != CoreConfigType.raw.name) {
      throw StateError('Unsupported asset type');
    }
    return await (update(coreConfig)..where(
              (table) =>
                  table.id.equals(entry.id) & table.type.equals(entry.type),
            ))
            .write(entry.toCompanion(false)) >
        0;
  }

  /// Internal/complete-restore insertion. Does not enforce asset types or limits.
  /// Ordinary additions and imports must use [insertAssetRow]/[insertAssetRows].
  Future<int> insertRow(CoreConfigCompanion entry) async {
    return into(coreConfig).insert(entry);
  }

  /// Internal/complete-restore batch; retained Raw rows may exceed the new limit.
  Future<int> insertRows(List<CoreConfigCompanion> entries) async {
    if (entries.isEmpty) {
      return 0;
    }
    await coreConfig.insertAll(entries);
    return entries.length;
  }

  static const maxRawConfigs = 3;

  Future<int> insertAssetRow(CoreConfigCompanion entry) =>
      attachedDatabase.transaction(() async {
        await _checkNewAssets([entry]);
        return insertRow(entry);
      });

  Future<int> insertAssetRows(List<CoreConfigCompanion> entries) =>
      attachedDatabase.transaction(() async {
        await _checkNewAssets(entries);
        return insertRows(entries);
      });

  Future<void> _checkNewAssets(List<CoreConfigCompanion> entries) async {
    var addedRaw = 0;
    for (final entry in entries) {
      final type = entry.type.present ? entry.type.value : null;
      if (type != CoreConfigType.outbound.name &&
          type != CoreConfigType.raw.name) {
        throw ArgumentError('Unsupported asset type');
      }
      if (type == CoreConfigType.raw.name) {
        addedRaw += 1;
      }
    }
    if (addedRaw == 0) {
      return;
    }
    final count = coreConfig.id.count();
    final row =
        await (selectOnly(coreConfig)
              ..addColumns([count])
              ..where(coreConfig.type.equals(CoreConfigType.raw.name)))
            .getSingle();
    if (row.read(count)! + addedRaw > maxRawConfigs) {
      throw StateError('At most three new Raw configurations are allowed');
    }
  }

  Future<int> copyRow(int coreConfigId) async {
    final entry = await searchRow(coreConfigId);
    if (entry == null) {
      return 0;
    }
    final row = entry
        .toCompanion(false)
        .copyWith(
          id: const Value.absent(),
          subId: const Value(DBConstants.defaultId),
          // A copy keeps asset metadata, but has no measurement of its own yet.
          delay: const Value(PingDelayConstants.unknown),
        );
    return insertAssetRow(row);
  }

  Future<int> deleteRow(CoreConfigData entry) async {
    final res = await (delete(
      coreConfig,
    )..where((tbl) => tbl.id.equals(entry.id))).go();
    // Subscription.count records the last successful import, not retained rows.
    notifyUpdates({TableUpdate.onTable(coreConfig, kind: UpdateKind.delete)});
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
    notifyUpdates({TableUpdate.onTable(coreConfig, kind: UpdateKind.delete)});
    return res;
  }

  Future<int> deleteUnreachableHomeNodeRows(int subId) =>
      deleteUnreachableOutboundRows(subId);

  Future<List<SubscriptionData>> _getAllSubscriptions() async {
    return select(subscription).get();
  }

  Future<int> clear() async {
    final res = await delete(coreConfig).go();
    return res;
  }
}
