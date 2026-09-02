import 'package:drift/drift.dart';

@DataClassName('CustomRoutingProfileData')
class CustomRoutingProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  // The asset writer supplies base64-encoded UTF-8 Xray JSON, as for CoreConfig.
  TextColumn get data => text()();
}
