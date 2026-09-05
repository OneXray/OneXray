import 'package:drift/drift.dart';

class ConnectionConfig extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  // App connection configuration, not native VPN runtime state.
  TextColumn get configurationJson =>
      text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
