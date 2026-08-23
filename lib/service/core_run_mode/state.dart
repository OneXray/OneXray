import 'package:flutter/foundation.dart';
import 'package:onexray/core/model/core_run_mode.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/service/localizations/service.dart';

export 'package:onexray/core/model/core_run_mode.dart';

abstract final class CoreRunModePolicy {
  static bool get proxyEnabled =>
      resolve(CoreRunMode.proxy) == CoreRunMode.proxy;

  static CoreRunMode resolve(CoreRunMode requested) {
    return resolveForEnvironment(
      requested,
      debugMode: kDebugMode,
      isIOS: AppPlatform.isIOS,
    );
  }

  @visibleForTesting
  static CoreRunMode resolveForEnvironment(
    CoreRunMode requested, {
    required bool debugMode,
    required bool isIOS,
  }) {
    return debugMode && isIOS ? requested : CoreRunMode.tun;
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
