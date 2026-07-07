import 'package:onexray/core/model/core_run_mode.dart';
import 'package:onexray/service/localizations/service.dart';

export 'package:onexray/core/model/core_run_mode.dart';

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
