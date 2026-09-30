import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/service/servers/outbound/map.dart';
import 'package:onexray/service/servers/outbound/state_db.dart';

class XrayShareReader {
  Future<List<CoreConfigCompanion>> parseShareText(
    String text, {
    String? ageSecretKey,
  }) async {
    final outbounds = await AppHostApi().convertShareLinksToXrayJson(
      text,
      ageSecretKey: ageSecretKey,
    );
    return readOutbounds(outbounds);
  }

  Future<List<CoreConfigCompanion>> readOutbounds(
    List<Map<String, dynamic>> outbounds,
  ) async {
    final res = <CoreConfigCompanion>[];

    for (var index = 0; index < outbounds.length; index++) {
      if (index > 0 && index % 64 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final outbound = copyOutboundMap(outbounds[index]);
      try {
        res.add(outboundCompanion(outbound));
      } catch (error, stackTrace) {
        ygLogger(
          "Failed to read imported outbound (${error.runtimeType})\n$stackTrace",
        );
      }
    }
    return res;
  }
}
