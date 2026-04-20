import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/core/tools/extensions.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state.dart';

extension XhttpDownloadStateValidator on XhttpDownloadState {
  void removeWhitespace() {
    address = address.removeWhitespace;
    port = port.removeWhitespace;

    xhttpHost = xhttpHost.removeWhitespace;
    xhttpPath = xhttpPath.removeWhitespace;

    serverName = serverName.removeWhitespace;
    pinnedPeerCertSha256 = pinnedPeerCertSha256.removeWhitespace;
    verifyPeerCertByName = verifyPeerCertByName.removeWhitespace;
    echConfigList = echConfigList.removeWhitespace;
    password = password.removeWhitespace;
    shortId = shortId.removeWhitespace;
    mldsa65Verify = mldsa65Verify.removeWhitespace;
    spiderX = spiderX.removeWhitespace;

    _removeWhitespaceExtra();
  }

  void _removeWhitespaceExtra() {
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
  }

  bool get isBlank {
    if (!_isBlankExtra) {
      return false;
    }

    if (EmptyTool.checkString(address)) {
      return false;
    }
    if (EmptyTool.checkString(port)) {
      return false;
    }

    if (EmptyTool.checkString(xhttpHost)) {
      return false;
    }
    if (EmptyTool.checkString(xhttpPath)) {
      return false;
    }
    if (xhttpMode != XhttpMode.auto) {
      return false;
    }

    if (security != StreamSettingsSecurity.tls) {
      return false;
    }
    if (EmptyTool.checkString(serverName)) {
      return false;
    }
    if (fingerprint != StreamSettingsSecurityFingerprint.none) {
      return false;
    }
    if (EmptyTool.checkString(pinnedPeerCertSha256)) {
      return false;
    }
    if (EmptyTool.checkString(verifyPeerCertByName)) {
      return false;
    }
    if (EmptyTool.checkString(echConfigList)) {
      return false;
    }
    if (EmptyTool.checkString(password)) {
      return false;
    }
    if (EmptyTool.checkString(shortId)) {
      return false;
    }
    if (EmptyTool.checkString(mldsa65Verify)) {
      return false;
    }
    if (EmptyTool.checkString(spiderX)) {
      return false;
    }

    return true;
  }

  bool get _isBlankExtra {
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

    return true;
  }
}
