import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';

class DocURLHelper {
  static const _domain = "onexray.com";

  static Uri docUri() {
    var path = "/";
    if (AppEventBus.instance.state.languageCode == LanguageCode.zh) {
      path = "/zh";
    }

    final uri = Uri.https(_domain, path);
    ygLogger("$uri");
    return uri;
  }

  static Uri creditsUri() {
    var path = "/docs/credits/";
    if (AppEventBus.instance.state.languageCode == LanguageCode.zh) {
      path = "/zh/docs/credits/";
    }

    final uri = Uri.https(_domain, path);
    ygLogger("$uri");
    return uri;
  }

  static Uri privacyUri() {
    var path = "/docs/privacy/";
    if (AppEventBus.instance.state.languageCode == LanguageCode.zh) {
      path = "/zh/docs/privacy/";
    }

    final uri = Uri.https(_domain, path);
    ygLogger("$uri");
    return uri;
  }
}
