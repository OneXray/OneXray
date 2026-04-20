import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state_validator.dart';
import 'package:onexray/service/xray/outbound/xhttp/state.dart';

extension XhttpExtraStateValidator on XhttpExtraState {
  void removeWhitespace() {
    final newHeaders = <String, String>{};
    headers.forEach((key, value) {
      final newKey = key.removeWhitespace;
      if (newKey.isNotEmpty) {
        final newValue = value.removeWhitespace;
        if (newValue.isNotEmpty) {
          newHeaders[newKey] = newValue;
        }
      }
    });
    headers = newHeaders;

    xPaddingBytes = xPaddingBytes.removeWhitespace;
    scMaxEachPostBytes = scMaxEachPostBytes.removeWhitespace;
    scMinPostsIntervalMs = scMinPostsIntervalMs.removeWhitespace;

    maxConcurrency = maxConcurrency.removeWhitespace;
    maxConnections = maxConnections.removeWhitespace;
    cMaxReuseTimes = cMaxReuseTimes.removeWhitespace;
    hMaxReusableSecs = hMaxReusableSecs.removeWhitespace;
    hMaxRequestTimes = hMaxRequestTimes.removeWhitespace;
    hKeepAlivePeriod = hKeepAlivePeriod.removeWhitespace;

    downloadSettings.removeWhitespace();
  }

  bool get isBlank {
    if (headers.isNotEmpty) {
      return false;
    }
    if (EmptyTool.checkString(xPaddingBytes)) {
      if (xPaddingBytes != "0") {
        return false;
      }
    }

    if (noGRPCHeader) {
      return false;
    }
    if (EmptyTool.checkString(scMaxEachPostBytes)) {
      if (scMaxEachPostBytes != "0") {
        return false;
      }
    }
    if (EmptyTool.checkString(scMinPostsIntervalMs)) {
      if (scMinPostsIntervalMs != "0") {
        return false;
      }
    }

    if (EmptyTool.checkString(maxConcurrency)) {
      if (maxConcurrency != "0") {
        return false;
      }
    }
    if (EmptyTool.checkString(maxConnections)) {
      if (maxConnections != "0") {
        return false;
      }
    }
    if (EmptyTool.checkString(cMaxReuseTimes)) {
      if (cMaxReuseTimes != "0") {
        return false;
      }
    }
    if (EmptyTool.checkString(hMaxReusableSecs)) {
      if (hMaxReusableSecs != "0") {
        return false;
      }
    }
    if (EmptyTool.checkString(hMaxRequestTimes)) {
      if (hMaxRequestTimes != "0") {
        return false;
      }
    }
    if (EmptyTool.checkString(hKeepAlivePeriod)) {
      if (hKeepAlivePeriod != "0") {
        return false;
      }
    }

    if (!downloadSettings.isBlank) {
      return false;
    }
    return true;
  }
}
