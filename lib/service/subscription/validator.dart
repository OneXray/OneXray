import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:tuple/tuple.dart';

class SubscriptionValidator {
  static Future<Tuple2<bool, String>> validate(String name, String url) async {
    if (name.isEmpty) {
      return Tuple2(false, appLocalizationsNoContext().validationNameRequired);
    }
    if (url.isEmpty) {
      return Tuple2(false, appLocalizationsNoContext().validationUrlRequired);
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return Tuple2(false, appLocalizationsNoContext().validationUrlInvalid);
    }
    final db = AppDatabase();
    final urlExists = await db.subscriptionDao.urlExists(url);
    if (urlExists) {
      return Tuple2(false, appLocalizationsNoContext().validationUrlDuplicate);
    }
    return Tuple2(true, "");
  }
}
