import 'dart:async';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:onexray/core/tools/platform.dart';
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

  static const int adsInterval = 10;
  static const int adsFixedCount = 5;

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

  Future<List<ConfigQueryRow>> _convertConfigQueryRows(
    List<TypedResult> rows,
  ) async {
    final groups = <int, ConfigGroup>{};
    final subscriptions = await _getAllSubscriptions();
    final localSub = await _readLocalSubscription();
    subscriptions.add(localSub);
    for (final sub in subscriptions) {
      final subItem = SubscriptionItem(sub, ConfigQueryRowType.subscription);
      final group = ConfigGroup(sub.id, subItem, []);
      groups[sub.id] = group;
    }
    for (final row in rows) {
      final data = _convertRowToCoreConfigData(row);
      final subId = data.subId;
      if (groups.containsKey(subId)) {
        final group = groups[subId]!;
        final outboundItem = ConfigItem(data, ConfigQueryRowType.config);
        group.configs.add(outboundItem);
        group.count += 1;
        if (AppPlatform.isMobile) {
          if (group.count % adsInterval == 0) {
            final adsItem = AdsItem(ConfigQueryRowType.ads);
            group.configs.add(adsItem);
          }
        }
      }
    }
    // fix ads
    for (final group in groups.values) {
      if (group.count > adsFixedCount &&
          group.count < adsInterval &&
          AppPlatform.isMobile) {
        group.configs.add(AdsItem(ConfigQueryRowType.ads));
      }
      group.subscription.count = group.count;
    }
    // fix local count
    final localGroup = groups[DBConstants.defaultId];
    if (localGroup != null) {
      var sub = localGroup.subscription.subscription;
      sub = sub.copyWith(count: localGroup.count);
      localGroup.subscription.subscription = sub;
    }

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
      final results = await _convertConfigQueryRows(rows);
      yield results;
    }
  }

  Future<List<ConfigQueryRow>> get allOutboundRows async {
    final query = _allConfigRowsQuery
      ..where(coreConfig.type.equals(CoreConfigType.outbound.name));
    final rows = await query.get();
    final results = await _convertConfigQueryRows(rows);
    return results;
  }

  Stream<List<ConfigQueryRow>> allSettingRowsStream() async* {
    final query = _allConfigRowsQuery
      ..where(coreConfig.type.equals(CoreConfigType.setting.name));
    final queryStream = query.watch();
    await for (final rows in queryStream) {
      final results = await _convertConfigQueryRows(rows);
      yield results;
    }
  }

  Future<List<ConfigQueryRow>> get allSettingRows async {
    final query = _allConfigRowsQuery
      ..where(coreConfig.type.equals(CoreConfigType.setting.name));
    final rows = await query.get();
    final results = await _convertConfigQueryRows(rows);
    return results;
  }

  Stream<List<ConfigQueryRow>> allRawRowsStream() async* {
    final query = _allConfigRowsQuery
      ..where(coreConfig.type.equals(CoreConfigType.raw.name));
    final queryStream = query.watch();
    await for (final rows in queryStream) {
      final results = await _convertConfigQueryRows(rows);
      yield results;
    }
  }

  Future<List<ConfigQueryRow>> get allRawRows async {
    final query = _allConfigRowsQuery
      ..where(coreConfig.type.equals(CoreConfigType.raw.name));
    final rows = await query.get();
    final results = await _convertConfigQueryRows(rows);
    return results;
  }

  Future<List<CoreConfigData>> allOutboundRowsWithDataBySubId(
    int subId,
  ) async =>
      (select(coreConfig)
            ..where((tbl) => tbl.type.equals(CoreConfigType.outbound.name))
            ..where((tbl) => tbl.subId.equals(subId)))
          .get();

  Future<List<CoreConfigData>> allRawRowsWithDataBySubId(int subId) async =>
      (select(coreConfig)
            ..where((tbl) => tbl.type.equals(CoreConfigType.raw.name))
            ..where((tbl) => tbl.subId.equals(subId)))
          .get();

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
              (tbl) => tbl.type.equals(CoreConfigType.setting.name).not(),
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

  Future<int> deleteUnreachableRows(int subId) async {
    final res =
        await (delete(coreConfig)
              ..where((tbl) => tbl.subId.equals(subId))
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
