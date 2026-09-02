import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/database/enum.dart';
import 'package:onexray/core/db/table/core_config.dart';
import 'package:onexray/core/db/table/subscription.dart';

part 'subscription.g.dart';

@DriftAccessor(tables: [Subscription, CoreConfig])
class SubscriptionDao extends DatabaseAccessor<AppDatabase>
    with _$SubscriptionDaoMixin {
  SubscriptionDao(super.db);

  Future<List<SubscriptionData>> get allRows async =>
      select(subscription).get();

  Future<SubscriptionData?> searchRow(int id) async {
    return (select(
      subscription,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<bool> urlExists(String url, {int? excludingId}) async {
    final query = select(subscription)..where((tbl) => tbl.url.equals(url));
    if (excludingId != null) {
      query.where((tbl) => tbl.id.equals(excludingId).not());
    }
    final res = await query.getSingleOrNull();
    return res != null;
  }

  Future<bool> updateRow(SubscriptionData entry) async {
    final result = await update(subscription).replace(entry);
    notifyUpdates({
      TableUpdate.onTable(coreConfig, kind: UpdateKind.update),
      TableUpdate.onTable(subscription, kind: UpdateKind.update),
    });
    return result;
  }

  Future<int> insertRow(SubscriptionCompanion entry) async {
    final result = await into(subscription).insert(entry);
    notifyUpdates({
      TableUpdate.onTable(coreConfig, kind: UpdateKind.update),
      TableUpdate.onTable(subscription, kind: UpdateKind.insert),
    });
    return result;
  }

  /// Explicit user deletion, after the connection layer resolves live references.
  /// Refreshes must use [deleteConfigs] instead; no orphan nodes are kept here.
  Future<int> deleteRow(int id) => attachedDatabase.transaction(() async {
    if (id <= 0) {
      return 0;
    }
    final result = await (delete(
      subscription,
    )..where((table) => table.id.equals(id))).go();
    if (result > 0) {
      await (delete(coreConfig)..where((table) => table.subId.equals(id))).go();
      notifyUpdates({
        TableUpdate.onTable(coreConfig, kind: UpdateKind.delete),
        TableUpdate.onTable(subscription, kind: UpdateKind.delete),
      });
    }
    return result;
  });

  Future<int> deleteConfigs(int subId, {required Set<int> protectedIds}) async {
    final query = delete(coreConfig)
      ..where((table) => table.subId.equals(subId))
      ..where((table) => table.type.equals(CoreConfigType.outbound.name))
      ..where((table) => table.favorite.equals(false));
    if (protectedIds.isNotEmpty) {
      query.where((table) => table.id.isNotIn(protectedIds));
    }
    return query.go();
  }

  Future<int> clear() async {
    final res = await delete(subscription).go();
    return res;
  }
}
