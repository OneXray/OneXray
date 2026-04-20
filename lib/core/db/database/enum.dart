import 'package:collection/collection.dart';

enum CoreConfigType {
  outbound("outbound"),
  setting("setting"),
  raw("raw");

  const CoreConfigType(this.name);

  final String name;

  @override
  String toString() => name;

  static CoreConfigType? fromString(String name) =>
      CoreConfigType.values.firstWhereOrNull((value) => value.name == name);

  static List<String> get names {
    return CoreConfigType.values.map((e) => e.name).toList();
  }
}
