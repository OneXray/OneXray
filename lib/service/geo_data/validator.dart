import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/geo_data/system_state.dart';
import 'package:tuple/tuple.dart';

class GeoDataValidator {
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
    if (name == SystemGeoDatName.geoSite.name ||
        name == SystemGeoDatName.geoIp.name) {
      return Tuple2(false, appLocalizationsNoContext().validationNameDuplicate);
    }
    final db = AppDatabase();
    final nameExists = await db.geoDataDao.nameExists(name);
    if (nameExists) {
      return Tuple2(false, appLocalizationsNoContext().validationNameDuplicate);
    }
    return Tuple2(true, "");
  }
}
