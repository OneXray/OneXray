import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/service/ping/batch.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/outbound/map.dart';

Future<int> pingOutbound(
  Map<String, dynamic> outbound,
  PingState pingState, {
  int fallbackDelay = PingDelayConstants.unknown,
}) async {
  requireCanonicalOutbound(outbound);
  final result = await PingBatchRunner.runSingle(
    PingBatchSource(encodeSingleOutbound(outbound)),
    pingState,
  );
  return result?.delay ?? fallbackDelay;
}
