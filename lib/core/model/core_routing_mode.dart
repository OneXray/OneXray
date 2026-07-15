import 'package:collection/collection.dart';

enum CoreRoutingMode {
  rule('rule'),
  global('global'),
  direct('direct');

  const CoreRoutingMode(this.name);

  final String name;

  @override
  String toString() => name;

  static CoreRoutingMode fromString(String? name) {
    return values.firstWhereOrNull((value) => value.name == name) ??
        CoreRoutingMode.rule;
  }
}
