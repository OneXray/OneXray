import 'package:collection/collection.dart';

enum CoreRunMode {
  tun("tun"),
  proxy("proxy");

  const CoreRunMode(this.name);

  final String name;

  @override
  String toString() => name;

  static CoreRunMode fromString(String? name) {
    return values.firstWhereOrNull((value) => value.name == name) ??
        CoreRunMode.tun;
  }
}
