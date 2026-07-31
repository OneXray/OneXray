import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/ping/batch.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/state_writer.dart';
import 'package:onexray/core/model/xray_standard.dart';

extension OutboundStatePing on OutboundState {
  Future<int> ping(
    PingState pingState, {
    int fallbackDelay = PingDelayConstants.unknown,
  }) async {
    final xrayJson = XrayJsonStandard.standard..outbounds = [this.xrayJson];
    final result = await PingBatchRunner.runSingle(
      PingBatchSource(JsonTool.encoder.convert(xrayJson.toJson())),
      pingState,
    );
    return result?.delay ?? fallbackDelay;
  }
}
