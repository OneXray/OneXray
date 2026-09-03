import 'package:drift/drift.dart';

@DataClassName('ConnectionStateData')
class ConnectionState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  // App state metadata, not an encoded Xray asset. Validation belongs to service.
  TextColumn get settingsJson => text().withDefault(const Constant('{}'))();

  // The immutable plan itself lives in run/plans/<id>/plan.json.
  TextColumn get confirmedPlanId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
