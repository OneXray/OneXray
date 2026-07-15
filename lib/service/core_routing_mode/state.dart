import 'package:onexray/core/model/core_routing_mode.dart';
import 'package:onexray/service/localizations/service.dart';

export 'package:onexray/core/model/core_routing_mode.dart';

extension CoreRoutingModeTitle on CoreRoutingMode {
  String get title {
    return switch (this) {
      CoreRoutingMode.rule => appLocalizationsNoContext().coreRoutingModeRule,
      CoreRoutingMode.global =>
        appLocalizationsNoContext().coreRoutingModeGlobal,
      CoreRoutingMode.direct =>
        appLocalizationsNoContext().coreRoutingModeDirect,
    };
  }
}
