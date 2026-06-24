import 'package:collection/collection.dart';

enum GeoDataListType {
  full("full"),
  domain("domain"),
  ip("ip");

  const GeoDataListType(this.name);

  final String name;

  @override
  String toString() => name;

  static GeoDataListType? fromString(String name) =>
      GeoDataListType.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return GeoDataListType.values.map((e) => e.name).toList();
  }
}

enum GeoDatCodesMode {
  select("select"),
  show("show");

  const GeoDatCodesMode(this.name);

  final String name;

  @override
  String toString() => name;

  static GeoDatCodesMode? fromString(String name) =>
      GeoDatCodesMode.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return GeoDatCodesMode.values.map((e) => e.name).toList();
  }
}

class GeoDataListParams {
  final GeoDataListType type;
  final GeoDatCodesMode mode;

  GeoDataListParams(this.type, this.mode);
}
