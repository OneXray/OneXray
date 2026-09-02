import 'package:drift/drift.dart';

@DataClassName('ConnectionStateData')
class ConnectionState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  IntColumn get revision => integer().withDefault(const Constant(0))();

  // App state metadata, not an encoded Xray asset. Validation belongs to service.
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();

  TextColumn get confirmedSnapshotJson => text().nullable()();

  TextColumn get pendingApplyJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
