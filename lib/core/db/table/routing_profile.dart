import 'package:drift/drift.dart';

class RoutingProfile extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  BoolColumn get advanced => boolean().withDefault(const Constant(false))();

  // The asset writer supplies base64-encoded UTF-8 Xray JSON, as for CoreConfig.
  TextColumn get data => text()();
}
