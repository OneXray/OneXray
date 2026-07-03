import 'package:collection/collection.dart';
import 'package:onexray/core/tools/platform.dart';

enum PerAppVPNMode {
  allow("allow"),
  disallow("disallow");

  const PerAppVPNMode(this.name);

  final String name;

  @override
  String toString() => name;

  static PerAppVPNMode? fromString(String? name) {
    if (name == null) {
      return null;
    }
    return PerAppVPNMode.values.firstWhereOrNull((value) => value.name == name);
  }

  static List<String> get names {
    return PerAppVPNMode.values.map((e) => e.name).toList();
  }
}

enum OnDemandRuleMode {
  connect("connect"),
  disconnect("disconnect");

  const OnDemandRuleMode(this.name);

  final String name;

  @override
  String toString() => name;

  static OnDemandRuleMode? fromString(String? name) {
    if (name == null) {
      return null;
    }
    return OnDemandRuleMode.values.firstWhereOrNull(
      (value) => value.name == name,
    );
  }

  static List<String> get names =>
      OnDemandRuleMode.values.map((e) => e.name).toList();
}

enum OnDemandRuleInterfaceType {
  any("any"),
  cellular("cellular"),
  wifi("wifi"),
  ethernet("ethernet");

  const OnDemandRuleInterfaceType(this.name);

  final String name;

  @override
  String toString() => name;

  static OnDemandRuleInterfaceType? fromString(String? name) {
    if (name == null) {
      return null;
    }
    return OnDemandRuleInterfaceType.values.firstWhereOrNull(
      (value) => value.name == name,
    );
  }

  static List<String> get names {
    if (AppPlatform.isIOS) {
      return _iOSInterfaceTypes.map((e) => e.name).toList();
    }
    if (AppPlatform.isMacOS) {
      return _macOSInterfaceTypes.map((e) => e.name).toList();
    }
    return OnDemandRuleInterfaceType.values.map((e) => e.name).toList();
  }

  static final _iOSInterfaceTypes = [
    OnDemandRuleInterfaceType.any,
    OnDemandRuleInterfaceType.cellular,
    OnDemandRuleInterfaceType.wifi,
  ];

  static final _macOSInterfaceTypes = [
    OnDemandRuleInterfaceType.any,
    OnDemandRuleInterfaceType.ethernet,
    OnDemandRuleInterfaceType.wifi,
  ];
}
