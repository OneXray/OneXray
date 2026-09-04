import 'package:collection/collection.dart';

enum CoreConfigType {
  outbound("outbound"),
  raw("raw");

  const CoreConfigType(this.name);

  final String name;

  @override
  String toString() => name;

  static CoreConfigType? fromString(String name) =>
      CoreConfigType.values.firstWhereOrNull((value) => value.name == name);
}
