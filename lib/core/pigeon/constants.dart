import 'package:onexray/core/pigeon/host_api.dart';
import 'package:path/path.dart' as p;

class VpnConstants {
  static const tunMtu = 1500;

  static const randomPort = "0";

  static String get datDir => p.join(AppHostApi().tunFilesDir, "dat");
  static const systemGeoTimestamp = "timestamp.txt";

  static String get runDir => p.join(AppHostApi().tunFilesDir, "run");

  static String get startPath => p.join(runDir, "start.json");
}
