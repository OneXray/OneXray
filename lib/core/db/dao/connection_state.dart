import 'package:drift/drift.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/db/table/connection_state.dart';

part 'connection_state.g.dart';

@DriftAccessor(tables: [ConnectionState])
class ConnectionStateDao extends DatabaseAccessor<AppDatabase>
    with _$ConnectionStateDaoMixin {
  ConnectionStateDao(super.db);

  static const _initial = ConnectionStateData(
    id: 1,
    revision: 0,
    settingsJson: '{}',
  );

  Future<ConnectionStateData> read() async =>
      await select(connectionState).getSingleOrNull() ?? _initial;

  Stream<ConnectionStateData> watch() =>
      select(connectionState).watchSingleOrNull().map((row) => row ?? _initial);

  Future<void> _ensureRow() async {
    await into(
      connectionState,
    ).insert(const ConnectionStateCompanion(), mode: InsertMode.insertOrIgnore);
  }

  /// Records only recovery intent; saved settings and the confirmed snapshot stay
  /// unchanged until commit. A second apply cannot replace an unresolved intent.
  Future<void> beginApply(int baseRevision, String pendingJson) =>
      attachedDatabase.transaction(() async {
        await _ensureRow();
        final changed =
            await (update(connectionState)..where(
                  (row) =>
                      row.revision.equals(baseRevision) &
                      row.pendingApplyJson.isNull(),
                ))
                .write(
                  ConnectionStateCompanion(
                    pendingApplyJson: Value(pendingJson),
                  ),
                );
        if (changed != 1) {
          throw StateError('Connection state changed or an apply is pending');
        }
      });

  /// The caller supplies already validated state and already encoded asset data.
  /// Asset mutations must use this database so all writes share this transaction.
  Future<void> commit({
    required int baseRevision,
    required String settingsJson,
    String? confirmedSnapshotJson,
    Future<void> Function()? writeAssets,
  }) => attachedDatabase.transaction(() async {
    await _ensureRow();
    if ((await read()).revision != baseRevision) {
      throw StateError('Connection state changed');
    }
    await writeAssets?.call();
    final changed =
        await (update(
          connectionState,
        )..where((row) => row.revision.equals(baseRevision))).write(
          ConnectionStateCompanion(
            revision: Value(baseRevision + 1),
            settingsJson: Value(settingsJson),
            confirmedSnapshotJson: Value(confirmedSnapshotJson),
            pendingApplyJson: const Value(null),
          ),
        );
    if (changed != 1) {
      throw StateError('Connection state changed');
    }
  });

  /// Exact comparison prevents a late cancellation from clearing another apply.
  Future<bool> clearPending(String expectedPendingJson) async =>
      await (update(connectionState)
            ..where((row) => row.pendingApplyJson.equals(expectedPendingJson)))
          .write(
            const ConnectionStateCompanion(pendingApplyJson: Value(null)),
          ) ==
      1;

  /// Restore/clear callers already own their surrounding data transaction.
  Future<void> reset() async {
    await delete(connectionState).go();
  }
}
