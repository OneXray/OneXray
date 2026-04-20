import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state_reader.dart';
import 'package:onexray/service/xray/outbound/xhttp/state.dart';

extension XhttpExtraStateReader on XhttpExtraState {
  bool readFromXrayJson(XrayXhttpSettings settings) {
    if (EmptyTool.checkMap(settings.headers)) {
      headers = settings.headers!;
    }
    if (EmptyTool.checkString(settings.xPaddingBytes)) {
      xPaddingBytes = settings.xPaddingBytes!;
    }
    if (settings.noGRPCHeader != null) {
      noGRPCHeader = settings.noGRPCHeader!;
    }
    if (EmptyTool.checkString(settings.scMaxEachPostBytes)) {
      scMaxEachPostBytes = settings.scMaxEachPostBytes!;
    }
    if (EmptyTool.checkString(settings.scMinPostsIntervalMs)) {
      scMinPostsIntervalMs = settings.scMinPostsIntervalMs!;
    }
    if (settings.xmux != null) {
      final xmux = settings.xmux!;
      if (EmptyTool.checkString(xmux.maxConcurrency)) {
        maxConcurrency = xmux.maxConcurrency!;
      }
      if (EmptyTool.checkString(xmux.maxConnections)) {
        maxConnections = xmux.maxConnections!;
      }
      if (EmptyTool.checkString(xmux.cMaxReuseTimes)) {
        cMaxReuseTimes = xmux.cMaxReuseTimes!;
      }
      if (EmptyTool.checkString(xmux.hMaxReusableSecs)) {
        hMaxReusableSecs = xmux.hMaxReusableSecs!;
      }
      if (EmptyTool.checkString(xmux.hMaxRequestTimes)) {
        hMaxRequestTimes = xmux.hMaxRequestTimes!;
      }
      if (xmux.hKeepAlivePeriod != null) {
        hKeepAlivePeriod = "${xmux.hKeepAlivePeriod!}";
      }
    }

    if (settings.downloadSettings != null) {
      if (!downloadSettings.readFromXrayJson(settings.downloadSettings!)) {
        return false;
      }
    }
    return true;
  }
}
