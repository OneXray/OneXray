import 'package:onexray/service/geo_data/service.dart';

final class SystemGeoDatService {
  static final SystemGeoDatService _singleton = SystemGeoDatService._internal();
  factory SystemGeoDatService() => _singleton;
  SystemGeoDatService._internal();

  Future<void> checkAssets() => GeoDataService().ensureInstalled();

  /// Backup staging only; this does not publish or overwrite installed data.
  Future<void> copyAssetsTo(String datPath) =>
      GeoDataService.copyBundledTo(datPath);
}
