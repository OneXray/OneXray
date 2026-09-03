import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:onexray/core/db/dao/routing_profile.dart';
import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/share/backup_model.dart';
import 'package:onexray/service/routing/custom_template.dart';

/// The ZIP's database projection. Configuration data is already base64 encoded.
final class BackupDatabaseContents {
  static const _retainedTypes = {'outbound', 'raw'};

  final int version;
  final List<BackupCoreConfigJson> coreConfigs;
  final List<BackupSubscriptionJson> subscriptions;
  final List<BackupGeoDataJson> geoDataList;
  final List<BackupRoutingProfileJson> routingProfiles;

  const BackupDatabaseContents({
    required this.version,
    required this.coreConfigs,
    required this.subscriptions,
    required this.geoDataList,
    required this.routingProfiles,
  });

  bool get _isCurrent => version == BackupManifestJson.currentVersion;

  Iterable<BackupCoreConfigJson> get _retainedConfigs =>
      coreConfigs.where((row) => _retainedTypes.contains(row.type));

  int get skippedCoreConfigCount =>
      coreConfigs.length - _retainedConfigs.length;

  static Future<BackupDatabaseContents> read(AppDatabase db) =>
      db.transaction(() async {
        final configs = await (db.select(
          db.coreConfig,
        )..where((table) => table.type.isIn(_retainedTypes))).get();
        final subscriptions = await db.subscriptionDao.allRows;
        final geoData = await db.geoDataDao.allRows;
        final custom = await db.routingProfileDao.allRows;
        return BackupDatabaseContents(
          version: BackupManifestJson.currentVersion,
          coreConfigs: [
            for (final row in configs)
              BackupCoreConfigJson(
                row.name,
                row.type,
                row.tags,
                row.data,
                id: row.id,
                subId: row.subId,
                delay: row.delay,
                countryCode: row.countryCode,
                favorite: row.favorite,
              ),
          ],
          subscriptions: [
            for (final row in subscriptions)
              BackupSubscriptionJson(
                row.name,
                row.url,
                row.ageSecretKey,
                row.agePublicKey,
                row.timestamp.millisecondsSinceEpoch,
                row.expanded,
                id: row.id,
                count: row.count,
                autoUpdate: row.autoUpdate,
              ),
          ],
          geoDataList: [
            for (final row in geoData)
              BackupGeoDataJson(
                row.name,
                row.type,
                row.url,
                row.timestamp.millisecondsSinceEpoch,
                row.categoryCount,
                row.ruleCount,
                id: row.id,
              ),
          ],
          routingProfiles: [
            for (final row in custom)
              BackupRoutingProfileJson(row.id, row.name, row.data),
          ],
        );
      });

  void validate() {
    if (!BackupManifestJson.supportedVersions.contains(version)) {
      throw const FormatException('Unsupported backup version');
    }
    if ((!_isCurrent && routingProfiles.isNotEmpty) ||
        routingProfiles.length > RoutingProfileDao.maxProfiles) {
      throw const FormatException('Invalid custom routing profile count');
    }
    for (final row in coreConfigs) {
      if (row.type == null ||
          (_retainedTypes.contains(row.type) &&
              (row.name == null || row.tags == null))) {
        throw const FormatException('Invalid backup core config metadata');
      }
    }
    for (final row in subscriptions) {
      if (row.name == null ||
          row.url == null ||
          row.timestamp == null ||
          row.expanded == null ||
          ((row.ageSecretKey == null) != (row.agePublicKey == null))) {
        throw const FormatException('Invalid backup subscription metadata');
      }
      DateTime.fromMillisecondsSinceEpoch(row.timestamp!);
    }
    final geoNames = <String>{};
    for (final row in geoDataList) {
      final name = row.name;
      if (name == null ||
          name.isEmpty ||
          name == '.' ||
          name == '..' ||
          name.contains(RegExp(r'[/\\\x00-\x1f:]')) ||
          {'geoip', 'geosite'}.contains(name.toLowerCase()) ||
          !geoNames.add(name.toLowerCase()) ||
          !{'domain', 'ip'}.contains(row.type) ||
          row.url == null ||
          row.timestamp == null ||
          row.categoryCount == null ||
          row.ruleCount == null) {
        throw const FormatException('Invalid backup GeoData metadata');
      }
      DateTime.fromMillisecondsSinceEpoch(row.timestamp!);
    }
    for (final row in routingProfiles) {
      if (row.name == null || row.data == null) {
        throw const FormatException('Invalid backup custom routing profile');
      }
      final template = CustomRoutingTemplate.parse(
        utf8.decode(base64Decode(row.data!)),
      );
      if (template.assets.isNotEmpty) {
        throw const FormatException(
          'Stored custom route must not contain an import manifest',
        );
      }
    }
    if (!_isCurrent) {
      return;
    }
    _validateIds(_retainedConfigs.map((row) => row.id));
    _validateIds(subscriptions.map((row) => row.id));
    _validateIds(geoDataList.map((row) => row.id));
    _validateIds(routingProfiles.map((row) => row.id));
    // Legacy subscription deletion could keep a running node after deleting its
    // subscription. Full backup preserves that orphan's original ID/subId/data;
    // it must neither invent a subscription nor silently relabel the node local.
    for (final row in _retainedConfigs) {
      if (row.subId == null ||
          row.subId! < DBConstants.defaultId ||
          row.delay == null ||
          row.favorite == null) {
        throw const FormatException('Invalid backup node metadata');
      }
    }
    for (final row in subscriptions) {
      if (row.count == null || row.count! < 0) {
        throw const FormatException('Invalid backup subscription counts');
      }
    }
  }

  /// Full replacement bypasses only the ordinary Raw creation limit.
  Future<List<SubscriptionData>> restore(AppDatabase db) async {
    validate();
    return db.transaction(() async {
      await db.coreConfigDao.clear();
      await db.subscriptionDao.clear();
      await db.geoDataDao.clear();
      await db.routingProfileDao.clear();
      await db.connectionStateDao.reset();

      for (final row in subscriptions) {
        await db.subscriptionDao.insertRow(
          SubscriptionCompanion.insert(
            id: _isCurrent ? Value(row.id!) : const Value.absent(),
            name: row.name!,
            url: row.url!,
            ageSecretKey: Value(row.ageSecretKey),
            agePublicKey: Value(row.agePublicKey),
            timestamp: DateTime.fromMillisecondsSinceEpoch(row.timestamp!),
            count: _isCurrent ? row.count! : 0,
            expanded: row.expanded!,
            autoUpdate: Value(row.autoUpdate ?? true),
          ),
        );
      }
      for (final row in geoDataList) {
        await db.geoDataDao.insertRow(
          GeoDataCompanion.insert(
            id: _isCurrent ? Value(row.id!) : const Value.absent(),
            name: row.name!,
            type: row.type!,
            url: row.url!,
            timestamp: DateTime.fromMillisecondsSinceEpoch(row.timestamp!),
            categoryCount: row.categoryCount!,
            ruleCount: row.ruleCount!,
          ),
        );
      }
      for (final row in _retainedConfigs) {
        await db.coreConfigDao.insertRow(
          CoreConfigCompanion.insert(
            id: _isCurrent ? Value(row.id!) : const Value.absent(),
            name: row.name!,
            type: row.type!,
            tags: row.tags!,
            data: Value(row.data),
            // Probe caches are disposable; restored nodes use the normal queue.
            delay: _isCurrent && row.type != 'outbound'
                ? row.delay!
                : PingDelayConstants.unknown,
            subId: _isCurrent ? row.subId! : DBConstants.defaultId,
            countryCode: Value(_isCurrent ? row.countryCode : null),
            favorite: Value(_isCurrent ? row.favorite! : false),
          ),
        );
      }
      for (final row in routingProfiles) {
        await db.routingProfileDao.insertRow(
          RoutingProfileCompanion.insert(
            id: Value(row.id!),
            name: row.name!,
            data: row.data!,
          ),
        );
      }
      return db.subscriptionDao.allRows;
    });
  }

  static void _validateIds(Iterable<int?> values) {
    final ids = <int>{};
    for (final id in values) {
      if (id == null || id <= DBConstants.defaultId || !ids.add(id)) {
        throw const FormatException('Invalid or duplicate backup row ID');
      }
    }
  }
}
