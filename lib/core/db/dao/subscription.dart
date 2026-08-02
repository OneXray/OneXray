import 'package:drift/drift.dart';
import 'package:onexray/core/constants/preferences.dart';
import 'package:onexray/core/db/database/database.dart';
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

  Future<int> deleteRow(int id) async {
    final res = await (delete(
      subscription,
    )..where((tbl) => tbl.id.equals(id))).go();
    await deleteConfigs(id);
    notifyUpdates({
      TableUpdate.onTable(coreConfig, kind: UpdateKind.delete),
      TableUpdate.onTable(subscription, kind: UpdateKind.delete),
    });
    return res;
  }

  Future<int> deleteConfigs(int subId) async {
    final runningConfigId = await PreferencesKey().readRunningConfigId();
    return (delete(coreConfig)
          ..where((tbl) => tbl.subId.equals(subId))
          ..where((tbl) => tbl.id.equals(runningConfigId).not()))
        .go();
  }

  Future<int> clear() async {
    final res = await delete(subscription).go();
    return res;
  }
}
