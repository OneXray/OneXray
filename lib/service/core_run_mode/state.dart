import 'package:flutter/foundation.dart';
import 'package:onexray/core/model/core_run_mode.dart';
import 'package:onexray/service/localizations/service.dart';

export 'package:onexray/core/model/core_run_mode.dart';

abstract final class CoreRunModePolicy {
  static const proxyEnabled = kDebugMode;

  static CoreRunMode resolve(CoreRunMode requested) {
    return resolveForBuild(requested, debugMode: proxyEnabled);
  }

  @visibleForTesting
  static CoreRunMode resolveForBuild(
    CoreRunMode requested, {
    required bool debugMode,
  }) {
    return debugMode ? requested : CoreRunMode.tun;
  }
}

extension CoreRunModeTitle on CoreRunMode {
  String get title {
    switch (this) {
      case CoreRunMode.tun:
        return appLocalizationsNoContext().coreRunModeTun;
      case CoreRunMode.proxy:
        return appLocalizationsNoContext().coreRunModeProxy;
    }
  }
}
