import 'package:onexray/core/tools/file.dart';
import 'package:onexray/service/geo_data/system_dat_service.dart';

typedef SystemGeoDataAssetCopier = Future<void> Function(String destination);

final class BackupDatStager {
  final SystemGeoDataAssetCopier _copySystemAssets;

  BackupDatStager({SystemGeoDataAssetCopier? copySystemAssets})
    : _copySystemAssets =
          copySystemAssets ?? SystemGeoDatService().copyAssetsTo;

  Future<void> stage({
    required String backupDatDir,
    required String destination,
  }) async {
    await FileTool.copyDir(backupDatDir, destination);
    await _copySystemAssets(destination);
  }
}
