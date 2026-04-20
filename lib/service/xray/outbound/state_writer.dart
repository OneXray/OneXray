import 'package:onexray/core/model/xray_json.dart';
import 'package:onexray/core/tools/empty.dart';
import 'package:onexray/service/xray/outbound/enum.dart';
import 'package:onexray/service/xray/outbound/state.dart';
import 'package:onexray/service/xray/outbound/xhttp/state_validator.dart';
import 'package:onexray/service/xray/outbound/xhttp/state_writer.dart';
import 'package:onexray/service/xray/standard.dart';

extension OutboundStateWriter on OutboundState {
  XrayOutbound get xrayJson {
    final outbound = XrayOutboundStandard.standard;
    outbound.name = name;
    outbound.protocol = protocol.name;

    switch (protocol) {
      case XrayOutboundProtocol.vless:
        outbound.settings = _vlessSettings.toJson();
        break;
      case XrayOutboundProtocol.vmess:
        outbound.settings = _vmessSettings.toJson();
      case XrayOutboundProtocol.shadowsocks:
        outbound.settings = _shadowsocksSettings.toJson();
        break;
      case XrayOutboundProtocol.trojan:
        outbound.settings = _trojanSettings.toJson();
        break;
      case XrayOutboundProtocol.socks:
        outbound.settings = _socksSettings.toJson();
        break;
      case XrayOutboundProtocol.hysteria:
        outbound.settings = _hysteriaSettings.toJson();
      default:
        break;
    }

    outbound.tag = tag;

    outbound.streamSettings = _streamSettings;
    outbound.mux = _mux;

    return outbound;
  }

  XrayOutboundVLESS get _vlessSettings {
    final settings = XrayOutboundVLESSStandard.standard;
    settings.address = address;
    settings.port = int.tryParse(port);
    settings.id = vlessId;
    if (vlessFlow != VLESSFlow.none) {
      settings.flow = vlessFlow.name;
    }
    settings.encryption = vlessEncryption;
    if (EmptyTool.checkString(vlessReverseTag)) {
      final reverse = XrayOutboundVLESSReverseStandard.standard;
      reverse.tag = vlessReverseTag;
      settings.reverse = reverse;
    }

    return settings;
  }

  XrayOutboundVMess get _vmessSettings {
    final settings = XrayOutboundVMessStandard.standard;
    settings.address = address;
    settings.port = int.tryParse(port);
    settings.id = vmessId;
    settings.security = vmessSecurity.name;

    return settings;
  }

  XrayOutboundShadowsocks get _shadowsocksSettings {
    final settings = XrayOutboundShadowsocksStandard.standard;
    settings.address = address;
    settings.port = int.tryParse(port);
    settings.method = shadowsocksMethod.name;
    settings.password = shadowsocksPassword;
    settings.uot = shadowsocksUot;
    if (shadowsocksUotVersion != ShadowsocksUoTVersion.none) {
      settings.uotVersion = int.tryParse(shadowsocksUotVersion.name);
    }
    return settings;
  }

  XrayOutboundTrojan get _trojanSettings {
    final settings = XrayOutboundTrojanStandard.standard;
    settings.address = address;
    settings.port = int.tryParse(port);
    settings.password = trojanPassword;
    return settings;
  }

  XrayOutboundSocks get _socksSettings {
    final settings = XrayOutboundSocksStandard.standard;
    settings.address = address;
    settings.port = int.tryParse(port);

    if (EmptyTool.checkString(socksUser)) {
      settings.user = socksUser;
      if (socksPass.isNotEmpty) {
        settings.pass = socksPass;
      }
    }

    return settings;
  }

  XrayOutboundHysteria get _hysteriaSettings {
    final settings = XrayOutboundHysteriaStandard.standard;
    settings.version = int.tryParse(hysteriaVersion);
    settings.address = address;
    settings.port = int.tryParse(port);

    return settings;
  }

  XrayStreamSettings get _streamSettings {
    final streamSettings = XrayStreamSettingsStandard.standard;

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
    switch (network) {
      case StreamSettingsNetwork.raw:
        streamSettings.rawSettings = _rawSettings;
        break;
      case StreamSettingsNetwork.ws:
        streamSettings.wsSettings = _wsSettings;
        break;
      case StreamSettingsNetwork.kcp:
        streamSettings.kcpSettings = _kcpSettings;
        break;
      case StreamSettingsNetwork.grpc:
        streamSettings.grpcSettings = _grpcSettings;
        break;
      case StreamSettingsNetwork.httpupgrade:
        streamSettings.httpupgradeSettings = _httpupgradeSettings;
        break;
      case StreamSettingsNetwork.xhttp:
        streamSettings.xhttpSettings = _xhttpSettings;
        break;
      case StreamSettingsNetwork.hysteria:
        streamSettings.hysteriaSettings = _streamHysteriaSettings;
        break;
    }

    if (finalMask.isNotEmpty) {
      streamSettings.finalmask = finalMask;
    }

    streamSettings.sockopt = _sockopt;
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

  XrayRawSettings? get _rawSettings {
    if (rawHeaderType != RawHeaderType.none) {
      final request = XrayRawSettingsHeaderRequestStandard.standard;
      if (EmptyTool.checkList(rawPath)) {
        request.path = rawPath;
      }
      if (EmptyTool.checkList(rawHost)) {
        final headers = XrayRawSettingsHeaderRequestHeaders(rawHost);
        request.headers = headers;
      }
      final header = XrayRawSettingsHeader(rawHeaderType.name, request);
      return XrayRawSettings(header);
    }
    return null;
  }

  XrayWsSettings get _wsSettings {
    final wsSettings = XrayWsSettingsStandard.standard;
    if (EmptyTool.checkString(wsPath)) {
      wsSettings.path = wsPath;
    }
    if (EmptyTool.checkString(wsHost)) {
      wsSettings.host = wsHost;
    }
    return wsSettings;
  }

  XrayKcpSettings get _kcpSettings {
    final kcpSettings = XrayKcpSettingsStandard.standard;
    if (kcpHeaderType != KcpHeaderType.none) {
      final header = XrayKcpHeaderStandard.standard;
      header.type = kcpHeaderType.name;
      if (kcpHeaderDomain.isNotEmpty) {
        header.domain = kcpHeaderDomain;
      }
      kcpSettings.header = header;
    }
    if (EmptyTool.checkString(kcpSeed)) {
      kcpSettings.seed = kcpSeed;
    }
    return kcpSettings;
  }

  XrayGrpcSettings get _grpcSettings {
    final grpcSettings = XrayGrpcSettingsStandard.standard;
    if (EmptyTool.checkString(grpcAuthority)) {
      grpcSettings.authority = grpcAuthority;
    }
    if (EmptyTool.checkString(grpcServiceName)) {
      grpcSettings.serviceName = grpcServiceName;
    }
    grpcSettings.multiMode = grpcMultiMode;
    return grpcSettings;
  }

  XrayHttpupgradeSettings get _httpupgradeSettings {
    final httpupgradeSettings = XrayHttpupgradeSettingsStandard.standard;
    if (EmptyTool.checkString(httpupgradeHost)) {
      httpupgradeSettings.host = httpupgradeHost;
    }
    if (EmptyTool.checkString(httpupgradePath)) {
      httpupgradeSettings.path = httpupgradePath;
    }
    return httpupgradeSettings;
  }

  XrayXhttpSettings get _xhttpSettings {
    final xhttpSettings = XrayXhttpSettingsStandard.standard;
    if (EmptyTool.checkString(xhttpHost)) {
      xhttpSettings.host = xhttpHost;
    }
    if (EmptyTool.checkString(xhttpPath)) {
      xhttpSettings.path = xhttpPath;
    }
    xhttpSettings.mode = xhttpMode.name;

    if (!xhttpExtra.isBlank) {
      xhttpSettings.extra = xhttpExtra.xrayJson;

      // fix stream-one can not use downloadSettings
      if (xhttpMode == XhttpMode.streamOne) {
        xhttpSettings.extra?.downloadSettings = null;
      }
    }

    return xhttpSettings;
  }

  XrayHysteriaSettings get _streamHysteriaSettings {
    final hysteriaSettings = XrayHysteriaSettingsStandard.standard;
    hysteriaSettings.version = int.tryParse(hysteriaVersion);
    if (EmptyTool.checkString(hysteriaAuth)) {
      hysteriaSettings.auth = hysteriaAuth;
    }
    if (EmptyTool.checkString(hysteriaUp)) {
      hysteriaSettings.up = hysteriaUp;
    }
    if (EmptyTool.checkString(hysteriaDown)) {
      hysteriaSettings.down = hysteriaDown;
    }
    if (EmptyTool.checkString(hysteriaUdphopPort)) {
      final udphop = XrayHysteriaSettingsUdphopStandard.standard;
      udphop.port = hysteriaUdphopPort;
      udphop.interval = int.tryParse(hysteriaUdphopInterval);
      hysteriaSettings.udphop = udphop;
    }

    return hysteriaSettings;
  }

  XraySockopt get _sockopt {
    final sockopt = XraySockoptStandard.standard;
    if (tcpFastOpen) {
      sockopt.tcpFastOpen = tcpFastOpen;
    }
    if (EmptyTool.checkString(dialerProxy)) {
      sockopt.dialerProxy = dialerProxy;
    }
    if (EmptyTool.checkString(interface)) {
      sockopt.interface = interface;
    }
    if (tcpMptcp) {
      sockopt.tcpMptcp = tcpMptcp;
    }
    return sockopt;
  }

  XrayMux? get _mux {
    if (muxEnabled) {
      final mux = XrayMuxStandard.standard;
      mux.enabled = true;
      mux.xudpProxyUDP443 = muxXudpProxyUDP443.name;
      if (EmptyTool.checkString(muxConcurrency)) {
        mux.concurrency = int.tryParse(muxConcurrency);
      }
      if (EmptyTool.checkString(muxXudpConcurrency)) {
        mux.xudpConcurrency = int.tryParse(muxXudpConcurrency);
      }
      return mux;
    }
    return null;
  }
}
