import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/service/localizations/service.dart';
import 'package:onexray/service/geo_data/model.dart';
import 'package:tuple/tuple.dart';

class GeoDataValidator {
  static Future<Tuple2<bool, String>> validate(String name, String url) async {
    if (name.isEmpty) {
      return Tuple2(false, appLocalizationsNoContext().validationNameRequired);
    }
    if (url.isEmpty) {
      return Tuple2(false, appLocalizationsNoContext().validationUrlRequired);
    }
    try {
      GeoDataInput.httpsUri(url.trim());
    } catch (_) {
      return Tuple2(false, appLocalizationsNoContext().validationUrlInvalid);
    }
    String fileName;
    try {
      fileName = GeoDataInput.canonicalFileName(name);
    } catch (_) {
      return Tuple2(false, appLocalizationsNoContext().prototypeEnterFileName);
    }
    final rows = await AppDatabase().geoDataDao.publishedRows;
    if (rows.any(
      (row) => '${row.name}.dat'.toLowerCase() == fileName.toLowerCase(),
    )) {
      return Tuple2(false, appLocalizationsNoContext().validationNameDuplicate);
    }
    return Tuple2(true, "");
  }
}
