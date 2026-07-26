import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/service/ping/batch.dart';
import 'package:onexray/service/ping/state.dart';

class XrayRawPing {
  static Future<int> ping(
    String rawText,
    PingState pingState, {
    int fallbackDelay = PingDelayConstants.unknown,
  }) async {
    final results = await PingBatchRunner.run([
      PingBatchSource(rawText),
    ], pingState);
    if (results.isEmpty) {
      return fallbackDelay;
    }
    return results.first.delay;
  }
}
