import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/xhttp/download/state.dart';

extension XhttpDownloadStateReader on XhttpDownloadState {
  bool readFromXrayJson(XrayStreamSettings settings) {
    if (EmptyTool.checkString(settings.address)) {
      address = settings.address!;
    }

    if (settings.port != null) {
      port = "${settings.port!}";
    }

    if (settings.xhttpSettings != null) {
      if (!_parseXhttpSettings(settings.xhttpSettings!)) {
        return false;
      }
    }

    if (EmptyTool.checkString(settings.security)) {
      final security = StreamSettingsSecurity.fromString(settings.security!);
      if (security != null) {
        this.security = security;
      } else {
        return false;
      }
    }

    switch (security) {
      case StreamSettingsSecurity.tls:
        if (settings.tlsSettings != null) {
          if (!_parseTlsSettings(settings.tlsSettings!)) {
            return false;
          }
        }
        break;
      case StreamSettingsSecurity.reality:
        if (settings.realitySettings != null) {
          if (!_parseRealitySettings(settings.realitySettings!)) {
            return false;
          }
        }
        break;
      default:
        return false;
    }

    if (settings.xhttpSettings != null) {
      _readExtraSettings(settings.xhttpSettings!);
    }

    return true;
  }

  bool _parseXhttpSettings(XrayXhttpSettings settings) {
    if (EmptyTool.checkString(settings.host)) {
      xhttpHost = settings.host!;
    }
    if (EmptyTool.checkString(settings.path)) {
      xhttpPath = settings.path!;
    }
    if (EmptyTool.checkString(settings.mode)) {
      final mode = XhttpMode.fromString(settings.mode!);
      if (mode == null) {
        return false;
      }
      xhttpMode = mode;
    }
    return true;
  }

  bool _parseTlsSettings(XrayTlsSettings settings) {
    if (EmptyTool.checkString(settings.serverName)) {
      serverName = settings.serverName!;
    }
    if (EmptyTool.checkList(settings.alpn)) {
      alpn = StreamSettingsSecurityALPN.fromStrings(settings.alpn!);
    }
    if (EmptyTool.checkString(settings.fingerprint)) {
      final fingerprint = StreamSettingsSecurityFingerprint.fromString(
        settings.fingerprint!,
      );
      if (fingerprint == null) {
        return false;
      }
      this.fingerprint = fingerprint;
    }
    if (EmptyTool.checkString(settings.pinnedPeerCertSha256)) {
      pinnedPeerCertSha256 = settings.pinnedPeerCertSha256!;
    }
    if (EmptyTool.checkString(settings.verifyPeerCertByName)) {
      verifyPeerCertByName = settings.verifyPeerCertByName!;
    }
    if (EmptyTool.checkString(settings.echConfigList)) {
      echConfigList = settings.echConfigList!;
    }
    if (EmptyTool.checkString(settings.echForceQuery)) {
      final echForceQuery = StreamSettingsEchForceQuery.fromString(
        settings.echForceQuery!,
      );
      if (echForceQuery == null) {
        return false;
      }
      this.echForceQuery = echForceQuery;
    }
    return true;
  }

  bool _parseRealitySettings(XrayRealitySettings settings) {
    if (EmptyTool.checkString(settings.fingerprint)) {
      final fingerprint = StreamSettingsSecurityFingerprint.fromString(
        settings.fingerprint!,
      );
      if (fingerprint == null) {
        return false;
      }
      this.fingerprint = fingerprint;
    }
    if (EmptyTool.checkString(settings.serverName)) {
      serverName = settings.serverName!;
    }
    if (EmptyTool.checkString(settings.password)) {
      password = settings.password!;
    } else if (EmptyTool.checkString(settings.publicKey)) {
      password = settings.publicKey!;
    }
    if (EmptyTool.checkString(settings.shortId)) {
      shortId = settings.shortId!;
    }
    if (EmptyTool.checkString(settings.mldsa65Verify)) {
      mldsa65Verify = settings.mldsa65Verify!;
    }
    if (EmptyTool.checkString(settings.spiderX)) {
      spiderX = settings.spiderX!;
    }
    return true;
  }

  bool _readExtraSettings(XrayXhttpSettings settings) {
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

    return true;
  }
}
