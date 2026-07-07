import 'package:collection/collection.dart';

enum GeoDataType {
  domain("domain"),
  ip("ip");

  const GeoDataType(this.name);

  final String name;

  @override
  String toString() => name;

  static GeoDataType? fromString(String name) =>
      GeoDataType.values.firstWhereOrNull((value) => value.name == name);
}
