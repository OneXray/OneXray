import 'package:drift/drift.dart';

class Subscription extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get url => text()();

  DateTimeColumn get timestamp => dateTime()();

  IntColumn get count => integer()();

  BoolColumn get expanded => boolean()();
}
