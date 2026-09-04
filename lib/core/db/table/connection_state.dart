import 'package:drift/drift.dart';

class ConnectionState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  // App state metadata, not an encoded Xray asset. Validation belongs to service.
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
