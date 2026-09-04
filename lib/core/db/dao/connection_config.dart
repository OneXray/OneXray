import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/table/connection_config.dart';

part 'connection_config.g.dart';

@DriftAccessor(tables: [ConnectionConfig])
class ConnectionConfigDao extends DatabaseAccessor<AppDatabase>
    with _$ConnectionConfigDaoMixin {
  ConnectionConfigDao(super.db);

  static const _initial = ConnectionConfigData(id: 1, configurationJson: '{}');

  Future<ConnectionConfigData> read() async =>
      await select(connectionConfig).getSingleOrNull() ?? _initial;

  Stream<ConnectionConfigData> watch() =>
      select(connectionConfig)
          .watchSingleOrNull()
          .map((row) => row ?? _initial);

  Future<void> _ensureRow() async {
    await into(connectionConfig).insert(
      const ConnectionConfigCompanion(),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// The caller supplies validated configuration and encoded asset data.
  /// Asset mutations must use this database so all writes share this transaction.
  Future<void> commit({
    required String configurationJson,
    Future<void> Function()? writeAssets,
  }) => attachedDatabase.transaction(() async {
    await _ensureRow();
    await writeAssets?.call();
    final changed =
        await (update(
          connectionConfig,
        )..where((row) => row.id.equals(1))).write(
          ConnectionConfigCompanion(
            configurationJson: Value(configurationJson),
          ),
        );
    if (changed != 1) {
      throw StateError('Connection configuration is missing');
    }
  });

  /// Restore/clear callers already own their surrounding data transaction.
  Future<void> reset() async {
    await delete(connectionConfig).go();
  }
}
