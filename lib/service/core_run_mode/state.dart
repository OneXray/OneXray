import 'package:collection/collection.dart';
import 'package:onexray/service/localizations/service.dart';

enum CoreRunMode {
  tun("tun"),
  proxy("proxy");

  const CoreRunMode(this.name);

  final String name;

  @override
  String toString() => title;

  String get title {
    switch (this) {
      case CoreRunMode.tun:
        return appLocalizationsNoContext().coreRunModeTun;
      case CoreRunMode.proxy:
        return appLocalizationsNoContext().coreRunModeProxy;
    }
  }

  static CoreRunMode fromString(String? name) {
    return values.firstWhereOrNull((value) => value.name == name) ??
        CoreRunMode.tun;
  }
}
