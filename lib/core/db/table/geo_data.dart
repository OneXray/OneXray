import 'package:drift/drift.dart';

class GeoData extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get type => text()();

  TextColumn get url => text()();

  DateTimeColumn get timestamp => dateTime()();

  IntColumn get categoryCount => integer()();

  IntColumn get ruleCount => integer()();

  /// NULL preserves the pre-generation flat files without rewriting old rows.
  TextColumn get generation => text().nullable()();
}
