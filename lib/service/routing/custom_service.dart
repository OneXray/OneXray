import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/maintenance/data_maintenance.dart';
import 'package:onexray/service/routing/custom_template.dart';

/// The graphical editor and import share this strict asset boundary. The
/// connection coordinator owns confirmation and applying a currently used asset.
class CustomRoutingService {
  final AppDatabase database;

  CustomRoutingService(this.database);

  static CustomRoutingTemplate read(CustomRoutingProfileData row) =>
      CustomRoutingTemplate.parse(utf8.decode(base64Decode(row.data)));

  Future<int> save({
    int? id,
    required String name,
    required String text,
  }) => DataMaintenance.run(() async {
    name = name.trim();
    if (name.isEmpty || name.runes.length > 32) {
      throw const FormatException(
        'Custom route name must contain 1–32 characters',
      );
    }
    final template = CustomRoutingTemplate.parse(text);
    if (template.assets.isNotEmpty) {
      throw const FormatException('Prepare Geodata dependencies before saving');
    }
    final data = base64Encode(utf8.encode(template.encode()));
    return database.transaction(() async {
      if ((await database.customRoutingProfilesDao.allRows).any(
        (row) =>
            row.id != id && row.name.trim().toLowerCase() == name.toLowerCase(),
      )) {
        throw const FormatException('Custom route names must be unique');
      }
      if (id == null) {
        return database.customRoutingProfilesDao.insertRow(
          CustomRoutingProfilesCompanion.insert(name: name, data: data),
        );
      }
      final previous = await database.customRoutingProfilesDao.searchRow(id);
      if (previous == null) throw StateError('Custom route no longer exists');
      await database.customRoutingProfilesDao.updateRow(
        previous.copyWith(name: name, data: data),
      );
      return id;
    });
  });
}
