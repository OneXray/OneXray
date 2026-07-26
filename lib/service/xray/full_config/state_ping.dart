import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/ping/batch.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_reader.dart';
import 'package:onexray/service/xray/full_config/state_writer.dart';

extension XrayFullConfigStatePing on XrayFullConfigState {
  Future<int> ping(
    PingState pingState, {
    int fallbackDelay = PingDelayConstants.unknown,
  }) async {
    final results = await PingBatchRunner.run([
      PingBatchSource(JsonTool.encoder.convert(xrayJson.toJson())),
    ], pingState);
    if (results.isEmpty) {
      return fallbackDelay;
    }
    return results.first.delay;
  }
}

extension XrayFullConfigDataPing on CoreConfigData {
  Future<int> pingFullConfig(
    PingState pingState, {
    int fallbackDelay = PingDelayConstants.unknown,
  }) async {
    if (data == null || data!.isEmpty) {
      return fallbackDelay;
    }
    final state = XrayFullConfigState();
    state.readFromDbData(this);
    return state.ping(pingState, fallbackDelay: fallbackDelay);
  }
}
