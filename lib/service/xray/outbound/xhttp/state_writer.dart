import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state_validator.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state_writer.dart';
import 'package:onexray/service/xray/outbound/xhttp/state.dart';
import 'package:onexray/service/xray/standard.dart';

extension XhttpExtraStateWriter on XhttpExtraState {
  XrayXhttpSettings get xrayJson {
    final xhttpSettings = XrayXhttpSettingsStandard.standard;

    if (headers.isNotEmpty) {
      xhttpSettings.headers = headers;
    }
    if (xPaddingBytes.isNotEmpty) {
      xhttpSettings.xPaddingBytes = xPaddingBytes;
    }
    if (noGRPCHeader) {
      xhttpSettings.noGRPCHeader = noGRPCHeader;
    }
    if (scMaxEachPostBytes.isNotEmpty) {
      xhttpSettings.scMaxEachPostBytes = scMaxEachPostBytes;
    }
    if (scMinPostsIntervalMs.isNotEmpty) {
      xhttpSettings.scMinPostsIntervalMs = scMinPostsIntervalMs;
    }

    final xmux = XrayXhttpSettingsXmuxStandard.standard;
    if (maxConcurrency.isNotEmpty) {
      xmux.maxConcurrency = maxConcurrency;
    }
    if (maxConnections.isNotEmpty) {
      xmux.maxConnections = maxConnections;
    }
    if (cMaxReuseTimes.isNotEmpty) {
      xmux.cMaxReuseTimes = maxConnections;
    }
    if (hMaxReusableSecs.isNotEmpty) {
      xmux.hMaxReusableSecs = hMaxReusableSecs;
    }
    if (hMaxRequestTimes.isNotEmpty) {
      xmux.hMaxRequestTimes = hMaxRequestTimes;
    }
    if (hKeepAlivePeriod.isNotEmpty) {
      xmux.hKeepAlivePeriod = int.tryParse(hKeepAlivePeriod);
    }
    xhttpSettings.xmux = xmux;

    if (!downloadSettings.isBlank) {
      xhttpSettings.downloadSettings = downloadSettings.xrayJson;
    }

    return xhttpSettings;
  }
}
