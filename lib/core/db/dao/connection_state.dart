import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/table/connection_state.dart';

part 'connection_state.g.dart';

@DriftAccessor(tables: [ConnectionState])
class ConnectionStateDao extends DatabaseAccessor<AppDatabase>
    with _$ConnectionStateDaoMixin {
  ConnectionStateDao(super.db);

  static const _initial = ConnectionStateData(id: 1, settingsJson: '{}');

  Future<ConnectionStateData> read() async =>
      await select(connectionState).getSingleOrNull() ?? _initial;

  Stream<ConnectionStateData> watch() =>
      select(connectionState).watchSingleOrNull().map((row) => row ?? _initial);

  Future<void> _ensureRow() async {
    await into(
      connectionState,
    ).insert(const ConnectionStateCompanion(), mode: InsertMode.insertOrIgnore);
  }

  /// The caller supplies already validated state and already encoded asset data.
  /// Asset mutations must use this database so all writes share this transaction.
  Future<void> commit({
    required String settingsJson,
    String? confirmedPlanId,
    Future<void> Function()? writeAssets,
  }) => attachedDatabase.transaction(() async {
    await _ensureRow();
    await writeAssets?.call();
    final changed =
        await (update(connectionState)..where((row) => row.id.equals(1))).write(
          ConnectionStateCompanion(
            settingsJson: Value(settingsJson),
            confirmedPlanId: Value(confirmedPlanId),
          ),
        );
    if (changed != 1) {
      throw StateError('Connection state is missing');
    }
  });

  /// Restore/clear callers already own their surrounding data transaction.
  Future<void> reset() async {
    await delete(connectionState).go();
  }
}
