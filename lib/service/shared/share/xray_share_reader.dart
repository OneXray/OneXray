import 'package:flutter/foundation.dart';
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
    return readXrayJsonOutbounds({'outbounds': outbounds});
  }

  @visibleForTesting
  Future<List<CoreConfigCompanion>> readXrayJsonOutbounds(
    Map<String, dynamic> xrayJson,
  ) async {
    final res = <CoreConfigCompanion>[];
    final outbounds = xrayJson['outbounds'];
    if (outbounds is! List<dynamic>) {
      return res;
    }

    for (var index = 0; index < outbounds.length; index++) {
      if (index > 0 && index % 64 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final value = outbounds[index];
      if (value is! Map<String, dynamic>) {
        continue;
      }
      final outbound = copyOutboundMap(value);
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
