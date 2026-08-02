import 'package:drift/drift.dart';

class Subscription extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get url => text()();

  TextColumn get ageSecretKey => text().nullable()();

  TextColumn get agePublicKey => text().nullable()();

  DateTimeColumn get timestamp => dateTime()();

  IntColumn get count => integer()();

  BoolColumn get expanded => boolean()();
}
