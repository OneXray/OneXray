import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state.dart';
import 'package:onexray/service/xray/standard.dart';

extension XhttpDownloadStateWriter on XhttpDownloadState {
  XrayStreamSettings get xrayJson {
    final streamSettings = XrayStreamSettingsStandard.standard;
    streamSettings.address = address;
    streamSettings.port = int.tryParse(port);

    streamSettings.security = security.name;
    switch (security) {
      case StreamSettingsSecurity.tls:
        streamSettings.tlsSettings = _tlsSettings;
        break;
      case StreamSettingsSecurity.reality:
        streamSettings.realitySettings = _realitySettings;
        break;
      default:
        break;
    }

    streamSettings.network = network.name;
    streamSettings.xhttpSettings = _xhttpSettings;

    return streamSettings;
  }

  XrayTlsSettings get _tlsSettings {
    final tlsSettings = XrayTlsSettingsStandard.standard;
    if (EmptyTool.checkString(serverName)) {
      tlsSettings.serverName = serverName;
    }
    if (alpn.isNotEmpty) {
      tlsSettings.alpn = StreamSettingsSecurityALPN.toStrings(alpn);
    }
    if (fingerprint != StreamSettingsSecurityFingerprint.none) {
      tlsSettings.fingerprint = fingerprint.name;
    }
    if (pinnedPeerCertSha256.isNotEmpty) {
      tlsSettings.pinnedPeerCertSha256 = pinnedPeerCertSha256;
    }
    if (verifyPeerCertByName.isNotEmpty) {
      tlsSettings.verifyPeerCertByName = verifyPeerCertByName;
    }
    if (echConfigList.isNotEmpty) {
      tlsSettings.echConfigList = echConfigList;
    }
    if (echForceQuery != StreamSettingsEchForceQuery.none) {
      tlsSettings.echForceQuery = echForceQuery.name;
    }
    return tlsSettings;
  }

  XrayRealitySettings get _realitySettings {
    final realitySettings = XrayRealitySettingsStandard.standard;
    if (fingerprint != StreamSettingsSecurityFingerprint.none) {
      realitySettings.fingerprint = fingerprint.name;
    }
    if (EmptyTool.checkString(serverName)) {
      realitySettings.serverName = serverName;
    }
    if (EmptyTool.checkString(password)) {
      realitySettings.password = password;
    }
    if (EmptyTool.checkString(shortId)) {
      realitySettings.shortId = shortId;
    }
    if (EmptyTool.checkString(mldsa65Verify)) {
      realitySettings.mldsa65Verify = mldsa65Verify;
    }
    if (EmptyTool.checkString(spiderX)) {
      realitySettings.spiderX = spiderX;
    }
    return realitySettings;
  }

  XrayXhttpSettings get _xhttpSettings {
    final xhttpSettings = _xhttpSettingsWithExtra;
    if (EmptyTool.checkString(xhttpHost)) {
      xhttpSettings.host = xhttpHost;
    }
    if (EmptyTool.checkString(xhttpPath)) {
      xhttpSettings.path = xhttpPath;
    }
    xhttpSettings.mode = xhttpMode.name;
    return xhttpSettings;
  }

  XrayXhttpSettings get _xhttpSettingsWithExtra {
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

    return xhttpSettings;
  }
}
