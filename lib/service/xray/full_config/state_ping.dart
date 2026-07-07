import 'package:onexray/core/db/database/constants.dart';
import 'package:onexray/core/db/database/database.dart';
import 'package:onexray/core/network/ping_auth.dart';
import 'package:onexray/core/pigeon/host_api.dart';
import 'package:onexray/core/tools/file.dart';
import 'package:onexray/core/tools/json.dart';
import 'package:onexray/service/ping/state.dart';
import 'package:onexray/service/xray/full_config/state.dart';
import 'package:onexray/service/xray/full_config/state_reader.dart';
import 'package:onexray/service/xray/full_config/state_writer.dart';
import 'package:onexray/service/xray/profile/inbounds_state.dart';
import 'package:onexray/service/xray/raw/fix.dart';
import 'package:onexray/service/xray/raw/writer.dart';

extension XrayFullConfigStatePing on XrayFullConfigState {
  Future<int> ping(
    PingState pingState, {
    int fallbackDelay = PingDelayConstants.unknown,
  }) async {
    final ports = await XrayPorts.getPorts();
    if (ports == null) {
      return fallbackDelay;
    }
    final jsonMap = xrayJson.toJson();
    XrayRawFix.fixInboundsPort(jsonMap, ports);
    final text = JsonTool.encoder.convert(jsonMap);
    final configPath = await XrayRawWriter.writeConfig(text);
    final res = await AppHostApi().ping(
      configPath,
      pingState.timeout.toInt(),
      pingState.realUrl,
      ports.pingAuth.proxyUrl(ports.pingPort),
    );
    await FileTool.deleteFileIfExists(configPath);
    return res;
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
