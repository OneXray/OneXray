import 'dart:convert';

import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/routing/document.dart';
import 'package:onexray/service/routing/state.dart';

/// Converts the persisted Base64 UTF-8 Xray document to and from editable state.
extension RoutingProfileStateDb on RoutingProfileState {
  static RoutingProfileState read(RoutingProfileData row) =>
      readData(id: row.id, name: row.name, data: row.data);

  static RoutingProfileState readData({
    int? id,
    required String name,
    required String data,
  }) {
    if (name.trim().isEmpty || name.trim().runes.length > 32) {
      throw const FormatException('Invalid Custom routing profile name');
    }
    return RoutingProfileDocument.parse(
      utf8.decode(base64Decode(data)),
      id: id,
      name: name,
      allowMetadata: false,
    ).state;
  }

  String get databaseData => JsonTool.encodeJsonToBase64(xrayJson.toJson());

  RoutingProfileCompanion get insertCompanion =>
      RoutingProfileCompanion.insert(name: name, data: databaseData);

  RoutingProfileData updateData(RoutingProfileData row) =>
      row.copyWith(name: name, data: databaseData);
}
