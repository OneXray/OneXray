import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/l10n/localizations/app_localizations_en.dart';
import 'package:onexray/service/event_bus/service.dart';

AppLocalizations appLocalizationsNoContext() {
  final eventBus = AppEventBus.instance;
  final locale = eventBus.state.languageCode.locale;
  try {
    return lookupAppLocalizations(locale);
  } catch (_) {
    return AppLocalizationsEn();
  }
}
