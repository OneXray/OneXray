import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/event_bus/enum.dart';
import 'package:onexray/service/event_bus/service.dart';

class DocURLHelper {
  static const _domain = "onexray.com";

  static String _localizedRootPath() {
    return switch (AppEventBus.instance.state.languageCode) {
      LanguageCode.zh => "/zh",
      LanguageCode.ru => "/ru",
      _ => "/",
    };
  }

  static String _localizedDocsPath(String page) {
    return switch (AppEventBus.instance.state.languageCode) {
      LanguageCode.zh => "/zh/docs/$page/",
      LanguageCode.ru => "/ru/docs/$page/",
      _ => "/docs/$page/",
    };
  }

  static Uri docUri() {
    final path = _localizedRootPath();
    final uri = Uri.https(_domain, path);
    ygLogger("$uri");
    return uri;
  }

  static Uri creditsUri() {
    final path = _localizedDocsPath("credits");
    final uri = Uri.https(_domain, path);
    ygLogger("$uri");
    return uri;
  }

  static Uri privacyUri() {
    final path = _localizedDocsPath("privacy");
    final uri = Uri.https(_domain, path);
    ygLogger("$uri");
    return uri;
  }
}
